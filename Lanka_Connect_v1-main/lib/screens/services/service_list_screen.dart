import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/service_discovery_filter.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../ui/web/web_tokens.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/geo_utils.dart';
import '../../utils/location_lookup.dart';
import '../../utils/user_roles.dart';
import '../../widgets/service_map_preview.dart';
import 'service_detail_screen.dart';
import 'service_map_screen.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({
    super.key,
    this.showOnlyMine = false,
    this.initialFilter,
    this.initialCategory,
    this.initialQuery,
    this.initialDistrict,
    this.initialCity,
    this.initialNearMe,
    this.autoApplyInitialFilters = false,
  });

  final bool showOnlyMine;
  final ServiceDiscoveryFilter? initialFilter;
  final String? initialCategory;
  final String? initialQuery;
  final String? initialDistrict;
  final String? initialCity;
  final bool? initialNearMe;
  final bool autoApplyInitialFilters;

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  static const List<String> _quickCategories = [
    'Cleaning',
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Painting',
    'Gardening',
    'Moving',
    'Beauty',
    'Tutoring',
  ];
  static const List<String> _districtOptions = [
    'Colombo',
    'Gampaha',
    'Kalutara',
    'Kandy',
    'Galle',
    'Kurunegala',
    'Matara',
  ];
  static const Map<String, List<String>> _cityByDistrict = {
    'Colombo': [
      'Colombo 01',
      'Colombo 03',
      'Colombo 07',
      'Nugegoda',
      'Dehiwala',
      'Rajagiriya',
      'Battaramulla',
      'Kotte',
      'Maharagama',
      'Mount Lavinia',
    ],
    'Gampaha': [
      'Negombo',
      'Kadawatha',
      'Ja-Ela',
      'Wattala',
      'Gampaha',
      'Minuwangoda',
      'Kelaniya',
    ],
    'Kalutara': ['Panadura', 'Horana', 'Kalutara', 'Beruwala', 'Bandaragama'],
    'Kandy': ['Kandy', 'Peradeniya', 'Katugastota', 'Gampola', 'Digana'],
    'Galle': ['Galle', 'Hikkaduwa', 'Ambalangoda', 'Elpitiya', 'Karapitiya'],
    'Kurunegala': ['Kurunegala', 'Kuliyapitiya', 'Narammala', 'Pannala'],
    'Matara': ['Matara', 'Weligama', 'Akuressa', 'Dikwella'],
  };
  static const double _defaultRadiusKm = 10;
  static const double _maxRadiusKm = 100;
  static const int _pageSize = 20;

  int _currentLimit = _pageSize;

  final _categoryController = TextEditingController();
  final _queryController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  String _category = '';
  String _query = '';
  String _district = '';
  String _city = '';
  bool _nearMe = false;
  bool _onlyWithCoordinates = false;
  bool _requestingLocation = false;
  String? _nearMeError;
  _NearMeStatus _nearMeStatus = _NearMeStatus.idle;
  double _radiusKm = _defaultRadiusKm;
  double? _minPrice;
  double? _maxPrice;
  LatLng? _currentPosition;
  bool _autoNearMeRequested = false;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _hydrateInitialFilters();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _queryController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    FocusScope.of(context).unfocus();
    setState(() {
      _category = _categoryController.text.trim();
      _query = _queryController.text.trim();
      _district = _districtController.text.trim();
      _city = _cityController.text.trim();
      _minPrice = double.tryParse(_minPriceController.text.trim());
      _maxPrice = double.tryParse(_maxPriceController.text.trim());
    });
  }

  void _hydrateInitialFilters() {
    final filter = widget.initialFilter;
    _categoryController.text =
        filter?.normalizedCategory ?? (widget.initialCategory ?? '').trim();
    _queryController.text =
        filter?.normalizedQuery ?? (widget.initialQuery ?? '').trim();
    _districtController.text =
        filter?.normalizedDistrict ?? (widget.initialDistrict ?? '').trim();
    _cityController.text =
        filter?.normalizedCity ?? (widget.initialCity ?? '').trim();

    _category = _categoryController.text;
    _query = _queryController.text;
    _district = _districtController.text;
    _city = _cityController.text;

    _showFilters = filter?.autoApply ?? widget.autoApplyInitialFilters;
    if ((filter?.nearMe ?? widget.initialNearMe) == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleNearMeToggle(true);
      });
    }
  }

  void _toggleQuickCategory(String category) {
    final next = _category.toLowerCase() == category.toLowerCase()
        ? ''
        : category;
    _categoryController.text = next;
    setState(() {
      _category = next;
    });
  }

  Query<Map<String, dynamic>> _buildQuery(String role, String userId) {
    Query<Map<String, dynamic>> query = FirestoreRefs.services();

    if (widget.showOnlyMine) {
      query = query.where('providerId', isEqualTo: userId);
    } else if (role == UserRoles.seeker || role == UserRoles.guest) {
      query = query.where('status', whereIn: const ['approved', 'active']);
    }

    query = query.limit(_currentLimit);

    return query;
  }

  Future<void> _handleNearMeToggle(bool value) async {
    if (!value) {
      setState(() {
        _nearMe = false;
        _nearMeError = null;
        _nearMeStatus = _NearMeStatus.idle;
      });
      return;
    }

    setState(() {
      _requestingLocation = true;
      _nearMeError = null;
      _nearMeStatus = _NearMeStatus.requesting;
    });

    final result = await _resolveCurrentPositionDetailed();

    if (!mounted) return;
    setState(() {
      _requestingLocation = false;
      _nearMe = result.point != null;
      _currentPosition = result.point;
      _nearMeStatus = result.status;
      if (result.point == null) {
        _nearMeError = 'Location unavailable. Falling back to city/district.';
      }
    });
  }

  Future<_NearMeResult> _resolveCurrentPositionDetailed() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const _NearMeResult(
          status: _NearMeStatus.serviceDisabled,
          point: null,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const _NearMeResult(status: _NearMeStatus.denied, point: null);
      }
      if (permission == LocationPermission.deniedForever) {
        return const _NearMeResult(
          status: _NearMeStatus.deniedForever,
          point: null,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return _NearMeResult(
        status: _NearMeStatus.ready,
        point: LatLng(pos.latitude, pos.longitude),
      );
    } catch (_) {
      return const _NearMeResult(
        status: _NearMeStatus.unavailable,
        point: null,
      );
    }
  }

  void _autoEnableNearMeIfNeeded(String role) {
    if (_autoNearMeRequested ||
        widget.showOnlyMine ||
        (role != UserRoles.seeker && role != UserRoles.guest)) {
      return;
    }
    _autoNearMeRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleNearMeToggle(true);
    });
  }

  static const List<double> _radiusOptions = [2, 5, 10, 20, 25, 50, 75, 100];

  void _expandRadius() {
    if (_radiusKm >= _maxRadiusKm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Max radius reached. Try city/district filters.'),
        ),
      );
      return;
    }
    // Snap to next valid dropdown option
    final next = _radiusOptions.firstWhere(
      (v) => v > _radiusKm,
      orElse: () => _maxRadiusKm,
    );
    setState(() {
      _radiusKm = next;
    });
  }

  List<_ServiceViewItem> _applyClientFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String userDistrict,
    required String userCity,
  }) {
    final useGps = _nearMe && _currentPosition != null;
    final effectiveDistrict = useGps
        ? ''
        : (_nearMe ? userDistrict : _district);
    final effectiveCity = useGps ? '' : (_nearMe ? userCity : _city);

    final normalizedCategory = _category.toLowerCase();
    final normalizedQuery = _query.toLowerCase();
    final normalizedDistrict = effectiveDistrict.toLowerCase();
    final normalizedCity = effectiveCity.toLowerCase();

    final filtered = <_ServiceViewItem>[];
    for (final doc in docs) {
      final data = doc.data();
      final category = (data['category'] ?? '').toString().toLowerCase();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final district = (data['district'] ?? '').toString().toLowerCase();
      final city = (data['city'] ?? '').toString().toLowerCase();
      final price = (data['price'] is num)
          ? (data['price'] as num).toDouble()
          : 0.0;
      final point = GeoUtils.extractPoint(data);

      if (normalizedCategory.isNotEmpty && category != normalizedCategory) {
        continue;
      }
      if (normalizedQuery.isNotEmpty &&
          !title.contains(normalizedQuery) &&
          !description.contains(normalizedQuery) &&
          !category.contains(normalizedQuery)) {
        continue;
      }
      if (normalizedDistrict.isNotEmpty && district != normalizedDistrict) {
        continue;
      }
      if (normalizedCity.isNotEmpty && city != normalizedCity) {
        continue;
      }
      if (_minPrice != null && price < _minPrice!) continue;
      if (_maxPrice != null && price > _maxPrice!) continue;
      if (_onlyWithCoordinates && point == null) continue;

      double? distanceKm;
      if (useGps && point != null) {
        distanceKm = GeoUtils.distanceKm(
          fromLat: _currentPosition!.latitude,
          fromLng: _currentPosition!.longitude,
          toLat: point.latitude,
          toLng: point.longitude,
        );
        if (distanceKm > _radiusKm) {
          continue;
        }
      }

      filtered.add(
        _ServiceViewItem(doc: doc, point: point, distanceKm: distanceKm),
      );
    }

    filtered.sort((a, b) {
      if (useGps) {
        if (a.distanceKm != null && b.distanceKm != null) {
          return a.distanceKm!.compareTo(b.distanceKm!);
        }
        if (a.distanceKm != null) return -1;
        if (b.distanceKm != null) return 1;
      }
      final aTs = a.doc.data()['createdAt'];
      final bTs = b.doc.data()['createdAt'];
      final aMillis = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
      final bMillis = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
      return bMillis.compareTo(aMillis);
    });

    return filtered;
  }

  String _displayLocation(Map<String, dynamic> data) {
    final city = (data['city'] ?? '').toString().trim();
    final district = (data['district'] ?? '').toString().trim();
    if (city.isNotEmpty || district.isNotEmpty) {
      return '$city, $district';
    }
    return (data['location'] ?? '').toString();
  }

  Future<void> _openMapView(List<_ServiceViewItem> items) async {
    final mapItems = items
        .map((item) {
          final data = item.doc.data();
          final exactPoint = item.point;
          if (exactPoint != null) {
            return ServiceMapItem(
              serviceId: item.doc.id,
              title: (data['title'] ?? 'Service').toString(),
              locationLabel: _displayLocation(data),
              priceLabel: 'LKR ${data['price'] ?? ''}',
              point: exactPoint,
              isApproximate: false,
              pointSource: 'Exact',
              category: (data['category'] ?? '').toString(),
              providerId: (data['providerId'] ?? '').toString(),
            );
          }

          final resolved = LocationLookup.resolve(
            city: data['city'],
            district: data['district'],
          );
          if (resolved == null) return null;

          return ServiceMapItem(
            serviceId: item.doc.id,
            title: (data['title'] ?? 'Service').toString(),
            locationLabel: _displayLocation(data),
            priceLabel: 'LKR ${data['price'] ?? ''}',
            point: resolved.point,
            isApproximate: resolved.isApproximate,
            pointSource: resolved.sourceLabel,
            category: (data['category'] ?? '').toString(),
            providerId: (data['providerId'] ?? '').toString(),
          );
        })
        .whereType<ServiceMapItem>()
        .toList();

    if (mapItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No mappable locations found. Add city/district or coordinates to view services on map.',
          ),
        ),
      );
      return;
    }

    final selectedServiceId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            ServiceMapScreen(items: mapItems, initialCenter: _currentPosition),
      ),
    );

    if (!mounted || selectedServiceId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(serviceId: selectedServiceId),
      ),
    );
  }

  int _headerItemCount(
    List<_ServiceViewItem> items,
    bool isLoading,
    bool hasError,
    bool hasMore,
  ) {
    // Header slots: intro (if !showOnlyMine), chips (if !showOnlyMine), filters
    int headers = 1; // filters always
    if (!widget.showOnlyMine) headers += 2; // intro + chips
    if (isLoading || hasError || items.isEmpty) return headers + 1;
    // count bar + items + optional load-more
    return headers + 1 + items.length + (hasMore ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.users().doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? {};
        final role = UserRoles.normalize(userData['role']);
        final userDistrict = (userData['district'] ?? '').toString().trim();
        final userCity = (userData['city'] ?? '').toString().trim();
        _autoEnableNearMeIfNeeded(role);

        final content = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _buildQuery(role, user.uid).snapshots(),
          builder: (context, snapshot) {
            final items = snapshot.connectionState == ConnectionState.waiting
                ? <_ServiceViewItem>[]
                : snapshot.hasError
                ? <_ServiceViewItem>[]
                : _applyClientFilters(
                    snapshot.data?.docs ?? [],
                    userDistrict: userDistrict,
                    userCity: userCity,
                  );
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final hasError = snapshot.hasError;
            final totalDocs = (snapshot.data?.docs ?? []).length;
            final hasMore =
                !isLoading && !hasError && totalDocs >= _currentLimit;

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _headerItemCount(items, isLoading, hasError, hasMore),
              itemBuilder: (context, index) {
                // --- Header items (intro + chips + filters) ---
                int cursor = 0;

                // 0: Intro
                if (!widget.showOnlyMine) {
                  if (index == cursor) {
                    return MobilePageIntro(
                      title: 'Find Services',
                      subtitle: 'Discover top-rated professionals near you',
                    );
                  }
                  cursor++;
                }

                // 1: Category chips
                if (!widget.showOnlyMine) {
                  if (index == cursor) {
                    return SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: _quickCategories.map((category) {
                          final selected =
                              _category.toLowerCase() == category.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: selected,
                              showCheckmark: false,
                              label: Text(category),
                              onSelected: (_) => _toggleQuickCategory(category),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }
                  cursor++;
                }

                // 2: Filters
                if (index == cursor) {
                  if (kIsWeb) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.all(WebTokens.spacingMd),
                      child: Card(
                        elevation: 0,
                        color: isDark
                            ? const Color(0xFF111C31)
                            : WebTokens.surfaceMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            WebTokens.radiusMd,
                          ),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : WebTokens.border,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(WebTokens.spacingMd),
                          child: _filters(),
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: MobileSectionCard(
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: const Text('Filters'),
                          initiallyExpanded: _showFilters,
                          onExpansionChanged: (expanded) {
                            setState(() => _showFilters = expanded);
                          },
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: _filters(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                cursor++;

                // 3: Loading / Error / Empty states
                if (isLoading) {
                  if (index == cursor) {
                    return const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return const SizedBox.shrink();
                }
                if (hasError) {
                  if (index == cursor) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Failed to load services: ${snapshot.error}',
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
                if (items.isEmpty) {
                  if (index == cursor) {
                    if (_nearMe) {
                      return MobileStatePanel(
                        icon: Icons.location_off_outlined,
                        title: 'No nearby services found',
                        subtitle: _radiusKm >= _maxRadiusKm
                            ? 'Maximum radius reached.\nTry district/city filters.'
                            : 'Current radius: ${_radiusKm.toInt()} km',
                        tone: MobileStateTone.muted,
                        action: _radiusKm < _maxRadiusKm
                            ? ElevatedButton.icon(
                                onPressed: _expandRadius,
                                icon: const Icon(Icons.open_in_full, size: 16),
                                label: const Text('Expand radius'),
                              )
                            : null,
                      );
                    }
                    if (kIsWeb) {
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: Text('No services found.')),
                      );
                    }
                    return const MobileEmptyState(
                      title: 'No services found.',
                      icon: Icons.search_off,
                    );
                  }
                  return const SizedBox.shrink();
                }

                // 4: Count + Map view bar
                if (index == cursor) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${items.length} service${items.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openMapView(items),
                          icon: const Icon(Icons.map),
                          label: const Text('Map view'),
                        ),
                      ],
                    ),
                  );
                }
                cursor++;

                // 5+: Service items
                final serviceIndex = index - cursor;
                if (serviceIndex >= items.length) {
                  // Load more button
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _currentLimit += _pageSize;
                        }),
                        child: const Text('Load more'),
                      ),
                    ),
                  );
                }

                final item = items[serviceIndex];
                final data = item.doc.data();
                final point = item.point;
                final distance = item.distanceKm;
                final status = (data['status'] ?? 'pending').toString();
                final onSurface = Theme.of(context).colorScheme.onSurface;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              final rawImages = data['imageUrls'];
                              final imageUrls =
                                  rawImages is List && rawImages.isNotEmpty
                                  ? rawImages
                                  : null;
                              if (imageUrls == null) {
                                return const SizedBox.shrink();
                              }
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrls.first.toString(),
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const SizedBox(
                                      height: 140,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stack) =>
                                      const SizedBox.shrink(),
                                ),
                              );
                            },
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ServiceDetailScreen(serviceId: item.doc.id),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (data['title'] ?? 'Service')
                                              .toString(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: onSurface,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      MobileStatusChip(
                                        label: status,
                                        color: status == 'approved'
                                            ? MobileTokens.secondary
                                            : status == 'rejected'
                                            ? Colors.red
                                            : MobileTokens.accent,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if ((data['category'] ?? '')
                                          .toString()
                                          .trim()
                                          .isNotEmpty)
                                        _metaChip(
                                          context,
                                          Icons.category_outlined,
                                          (data['category'] ?? '').toString(),
                                        ),
                                      if (_displayLocation(
                                        data,
                                      ).trim().isNotEmpty)
                                        _metaChip(
                                          context,
                                          Icons.location_on_outlined,
                                          _displayLocation(data),
                                        ),
                                      _metaChip(
                                        context,
                                        Icons.payments_outlined,
                                        'LKR ${data['price'] ?? ''}',
                                      ),
                                    ],
                                  ),
                                  if (_nearMe) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      distance != null
                                          ? 'Distance: ${GeoUtils.formatKm(distance)}'
                                          : 'Distance: N/A',
                                      style: TextStyle(
                                        color: onSurface.withValues(
                                          alpha: 0.75,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (point != null)
                            ServiceMapPreview(
                              point: point,
                              title: (data['title'] ?? 'Service').toString(),
                              height: 130,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ServiceMapScreen(
                                    items: [
                                      ServiceMapItem(
                                        serviceId: item.doc.id,
                                        title: (data['title'] ?? 'Service')
                                            .toString(),
                                        locationLabel: _displayLocation(data),
                                        priceLabel:
                                            'LKR ${data['price'] ?? ''}',
                                        point: point,
                                        isApproximate: false,
                                        pointSource: 'Exact',
                                        category: (data['category'] ?? '')
                                            .toString(),
                                        providerId: (data['providerId'] ?? '')
                                            .toString(),
                                      ),
                                    ],
                                    initialCenter: point,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );

        if (!kIsWeb) {
          final roleVisuals = RoleVisuals.forRole(role);
          return MobilePageScaffold(
            title: widget.showOnlyMine ? 'My Services' : 'Services',
            subtitle: widget.showOnlyMine
                ? 'Manage and track your service listings'
                : 'Discover trusted local services near you',
            accentColor: roleVisuals.accent,
            useScaffold: true,
            body: content,
          );
        }

        return WebPageScaffold(
          title: widget.showOnlyMine ? 'My Services' : 'Service Marketplace',
          subtitle: widget.showOnlyMine
              ? 'Manage and review your posted services.'
              : 'Find and filter services across districts and cities.',
          useScaffold: false,
          child: content,
        );
      },
    );
  }

  Widget _filters() {
    InputDecoration filterDecoration(String labelText) {
      final scheme = Theme.of(context).colorScheme;
      return InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        isDense: true,
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: filterDecoration('Search services'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _categoryController.text.trim().isEmpty
                      ? null
                      : _categoryController.text.trim(),
                  decoration: filterDecoration('Category'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All categories'),
                    ),
                    ..._quickCategories.map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _categoryController.text = value ?? '';
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _districtController.text.trim().isEmpty
                      ? null
                      : _districtController.text.trim(),
                  decoration: filterDecoration('District'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All districts'),
                    ),
                    ..._districtOptions.map(
                      (district) => DropdownMenuItem<String>(
                        value: district,
                        child: Text(district),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _districtController.text = value ?? '';
                    setState(() => _cityController.text = '');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _cityController.text.trim().isEmpty
                      ? null
                      : _cityController.text.trim(),
                  decoration: filterDecoration('City'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All cities'),
                    ),
                    ...(_cityByDistrict[_districtController.text.trim()] ??
                              _cityByDistrict.values
                                  .expand((cities) => cities)
                                  .toSet()
                                  .toList()
                          ..sort())
                        .map(
                          (city) => DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          ),
                        ),
                  ],
                  onChanged: (value) {
                    _cityController.text = value ?? '';
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Text('Near me'),
                    const SizedBox(width: 8),
                    Switch(
                      value: _nearMe,
                      onChanged: _requestingLocation
                          ? null
                          : _handleNearMeToggle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_requestingLocation)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Requesting current location...',
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (_nearMeStatus == _NearMeStatus.serviceDisabled)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Location services are disabled. Please enable GPS.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (_nearMeStatus == _NearMeStatus.denied)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Location permission denied. You can retry near me.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (_nearMeStatus == _NearMeStatus.deniedForever)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Location permission denied permanently.',
                    style: TextStyle(fontSize: 12),
                  ),
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ),
          if (_nearMeError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_nearMeError!, style: const TextStyle(fontSize: 12)),
            ),
          if (_nearMe)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<double>(
                    value: _radiusKm,
                    decoration: filterDecoration('Radius'),
                    items: _radiusOptions
                        .map(
                          (v) => DropdownMenuItem<double>(
                            value: v,
                            child: Text('${v.toInt()} km'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _radiusKm = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: _onlyWithCoordinates,
                        onChanged: (value) {
                          setState(() {
                            _onlyWithCoordinates = value ?? false;
                          });
                        },
                      ),
                      const Flexible(
                        child: Text(
                          'Coordinates only',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  decoration: filterDecoration('Min price'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  decoration: filterDecoration('Max price'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _applyFilters,
                child: const Text('Filter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(BuildContext context, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceViewItem {
  const _ServiceViewItem({
    required this.doc,
    required this.point,
    required this.distanceKm,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final LatLng? point;
  final double? distanceKm;
}

enum _NearMeStatus {
  idle,
  requesting,
  ready,
  denied,
  deniedForever,
  serviceDisabled,
  unavailable,
}

class _NearMeResult {
  const _NearMeResult({required this.status, required this.point});

  final _NearMeStatus status;
  final LatLng? point;
}
