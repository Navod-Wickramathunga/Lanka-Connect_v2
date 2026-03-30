import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/service_discovery_filter.dart';
import '../../ui/theme/design_tokens.dart';
import '../../utils/display_name_utils.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/geo_utils.dart';
import '../../utils/profile_identity.dart';
import '../../utils/service_image_defaults.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/category_bar.dart';
import '../../widgets/promotion_section.dart';
import '../../widgets/service_card_enhanced.dart';
import '../services/service_detail_screen.dart';
import '../services/service_list_screen.dart';
import '../../widgets/shimmer_loading.dart';
import '../../utils/page_transitions.dart';

/// The enhanced seeker home screen matching the React SeekerHome component.
/// Combines BannerCarousel + CategoryBar + PromotionSection + Service grid
/// with the existing Firebase/Firestore backend.
class SeekerHomeScreen extends StatefulWidget {
  const SeekerHomeScreen({super.key});

  @override
  State<SeekerHomeScreen> createState() => _SeekerHomeScreenState();
}

class _SeekerHomeScreenState extends State<SeekerHomeScreen> {
  String _selectedCategory = '';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  LatLng? _currentPosition;
  bool _locationResolved = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _locationResolved = true;
        });
      }
    } catch (_) {
      // Silently ignore – location is optional for the home screen
    }
  }

  Query<Map<String, dynamic>> _buildServiceQuery() {
    Query<Map<String, dynamic>> query = FirestoreRefs.services()
        .where('status', whereIn: const ['approved', 'active'])
        .limit(100);
    return query;
  }

  String _displayLocation(Map<String, dynamic> data) {
    return DisplayNameUtils.locationLabel(
      city: data['city'],
      district: data['district'],
      fallback: (data['location'] ?? '').toString(),
    );
  }

  String? _computeDistance(Map<String, dynamic> data) {
    if (_currentPosition == null) return null;
    final point = GeoUtils.extractPoint(data);
    if (point == null) return null;
    final km = GeoUtils.distanceKm(
      fromLat: _currentPosition!.latitude,
      fromLng: _currentPosition!.longitude,
      toLat: point.latitude,
      toLng: point.longitude,
    );
    return GeoUtils.formatKm(km);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return RefreshIndicator(
      color: DesignTokens.brandPrimary,
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        slivers: [
          // Greeting header
          SliverToBoxAdapter(
            child: _buildGreetingHeader(context, user, isDark),
          ),

          // Search bar
          if (user?.isAnonymous == true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'You are browsing as guest. Create an account from the top-right icon to keep your bookings and chat history.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),

          // Search bar with suggestions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SeekerSearchBar(
                controller: _searchController,
                searchQuery: _searchQuery,
                onChanged: (value) => setState(() => _searchQuery = value),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                onSuggestionTap: (suggestion) {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceListScreen(
                        initialFilter: ServiceDiscoveryFilter(
                          category: suggestion.isCategory
                              ? suggestion.label
                              : null,
                          query: suggestion.isCategory
                              ? null
                              : suggestion.label,
                          autoApply: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Banner carousel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BannerCarousel(
                onCtaTap: (banner) {
                  final ctaText = banner.ctaText.toLowerCase();
                  final title = banner.title.toLowerCase();
                  final isProviderCta =
                      ctaText.contains('register') || title.contains('join');
                  if (isProviderCta) {
                    TigerFeedback.show(
                      context,
                      'Tiger note: provider sign-up is coming soon.',
                      tone: TigerFeedbackTone.info,
                    );
                    return;
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceListScreen(
                        initialFilter: ServiceDiscoveryFilter(
                          query: banner.title,
                          autoApply: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Category bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CategoryBar(
                selected: _selectedCategory,
                onSelected: (cat) {
                  setState(() => _selectedCategory = cat);
                  if (cat.trim().isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceListScreen(
                        initialFilter: ServiceDiscoveryFilter(
                          category: cat,
                          autoApply: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Promotions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PromotionSection(
                onViewAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ServiceListScreen(
                        initialFilter: ServiceDiscoveryFilter(autoApply: true),
                      ),
                    ),
                  );
                },
                onPromoTap: (category) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ServiceListScreen(
                        initialFilter: ServiceDiscoveryFilter(
                          category: category.isNotEmpty ? category : null,
                          autoApply: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Services section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategory.isEmpty
                        ? 'Popular Services'
                        : '$_selectedCategory Services',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_locationResolved)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: DesignTokens.brandPrimary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Nearby',
                          style: TextStyle(
                            fontSize: 12,
                            color: DesignTokens.brandPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Services grid (Firestore-backed)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _buildServiceQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: ShimmerServiceGrid(itemCount: 6),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }

              var docs = snapshot.data?.docs ?? [];

              // Client-side filtering for category & search
              if (_selectedCategory.isNotEmpty) {
                docs = docs
                    .where(
                      (doc) =>
                          (doc.data()['category'] ?? '')
                              .toString()
                              .toLowerCase() ==
                          _selectedCategory.toLowerCase(),
                    )
                    .toList();
              }
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                docs = docs.where((doc) {
                  final data = doc.data();
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final desc = (data['description'] ?? '')
                      .toString()
                      .toLowerCase();
                  final cat = (data['category'] ?? '').toString().toLowerCase();
                  return title.contains(query) ||
                      desc.contains(query) ||
                      cat.contains(query);
                }).toList();
              }

              docs.sort((a, b) {
                final aTs = a.data()['createdAt'];
                final bTs = b.data()['createdAt'];
                final aMillis = aTs is Timestamp
                    ? aTs.millisecondsSinceEpoch
                    : 0;
                final bMillis = bTs is Timestamp
                    ? bTs.millisecondsSinceEpoch
                    : 0;
                return bMillis.compareTo(aMillis);
              });

              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No services found',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedCategory.isNotEmpty
                              ? 'Try a different category or clear selection'
                              : 'Try adjusting your search',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.52,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final data = docs[index].data();
                    final imageUrl = resolvePrimaryServiceImageUrl(data: data);
                    final price = (data['price'] is num)
                        ? (data['price'] as num).toDouble()
                        : 0.0;
                    final rating = (data['rating'] is num)
                        ? (data['rating'] as num).toDouble()
                        : 0.0;
                    final reviewCount = (data['reviewCount'] is num)
                        ? (data['reviewCount'] as num).toInt()
                        : 0;

                    return ServiceCardEnhanced(
                      title: (data['title'] ?? 'Untitled Service').toString(),
                      category: (data['category'] ?? 'Other').toString(),
                      price: price,
                      imageUrl: imageUrl,
                      rating: rating,
                      reviewCount: reviewCount,
                      location: _displayLocation(data),
                      distance: _computeDistance(data),
                      onTap: () => Navigator.of(context).push(
                        SlideUpRoute(
                          builder: (_) =>
                              ServiceDetailScreen(serviceId: docs[index].id),
                        ),
                      ),
                    );
                  }, childCount: docs.length),
                ),
              );
            },
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(BuildContext context, User? user, bool isDark) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_cloudy;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nights_stay;
    }

    // Fetch name from Firestore profile (falls back to Auth displayName)
    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirestoreRefs.users().doc(user.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        String displayName = 'there';
        String profileImageUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          displayName = ProfileIdentity.displayNameFrom(
            data,
            authUser: user,
            fallback: 'there',
          ).split(' ').first;
          profileImageUrl = ProfileIdentity.profileImageUrlFrom(
            data,
            authUser: user,
          );
        } else {
          displayName = ProfileIdentity.displayNameFrom(
            null,
            authUser: user,
            fallback: 'there',
          ).split(' ').first;
          profileImageUrl = ProfileIdentity.profileImageUrlFrom(
            null,
            authUser: user,
          );
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      DesignTokens.brandPrimary.withValues(alpha: 0.3),
                      Colors.transparent,
                    ]
                  : [
                      DesignTokens.brandPrimary.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          greetingIcon,
                          size: 20,
                          color: DesignTokens.brandSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$greeting, $displayName!',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find the perfect service for your needs',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey[400]
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: DesignTokens.brandPrimary.withValues(
                  alpha: 0.15,
                ),
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                onBackgroundImageError: profileImageUrl.isNotEmpty
                    ? (exception, stackTrace) {}
                    : null,
                child: profileImageUrl.isEmpty
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: DesignTokens.brandPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Search suggestion model
// ---------------------------------------------------------------------------
class _SearchSuggestion {
  const _SearchSuggestion({
    required this.label,
    required this.icon,
    this.isCategory = false,
  });

  final String label;
  final IconData icon;
  final bool isCategory;
}

// ---------------------------------------------------------------------------
// Autocomplete search bar widget
// ---------------------------------------------------------------------------
class _SeekerSearchBar extends StatefulWidget {
  const _SeekerSearchBar({
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
    required this.onSuggestionTap,
  });

  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<_SearchSuggestion> onSuggestionTap;

  @override
  State<_SeekerSearchBar> createState() => _SeekerSearchBarState();
}

class _SeekerSearchBarState extends State<_SeekerSearchBar> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<_SearchSuggestion> _suggestions = [];
  bool _isLoading = false;

  // Category suggestions derived from CategoryBar
  static const _categorySuggestions = [
    _SearchSuggestion(
      label: 'Cleaning',
      icon: Icons.cleaning_services,
      isCategory: true,
    ),
    _SearchSuggestion(
      label: 'Plumbing',
      icon: Icons.plumbing,
      isCategory: true,
    ),
    _SearchSuggestion(
      label: 'Electrical',
      icon: Icons.electrical_services,
      isCategory: true,
    ),
    _SearchSuggestion(
      label: 'Carpentry',
      icon: Icons.carpenter,
      isCategory: true,
    ),
    _SearchSuggestion(
      label: 'Painting',
      icon: Icons.format_paint,
      isCategory: true,
    ),
    _SearchSuggestion(label: 'Gardening', icon: Icons.grass, isCategory: true),
    _SearchSuggestion(
      label: 'Moving',
      icon: Icons.local_shipping,
      isCategory: true,
    ),
    _SearchSuggestion(label: 'Beauty', icon: Icons.spa, isCategory: true),
    _SearchSuggestion(label: 'Tutoring', icon: Icons.school, isCategory: true),
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _updateSuggestions(widget.controller.text);
    } else {
      // Delay removal so tap events on overlay can fire first.
      Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
    }
  }

  Future<void> _updateSuggestions(String query) async {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      // Show all categories when input is empty
      _suggestions = List.of(_categorySuggestions);
      _showOverlay();
      return;
    }

    // Filter categories
    final catMatches = _categorySuggestions
        .where((s) => s.label.toLowerCase().contains(q))
        .toList();

    // Query Firestore for matching service titles
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('services')
          .where('status', whereIn: const ['approved', 'active'])
          .limit(50)
          .get();

      final serviceMatches = <_SearchSuggestion>[];
      final seen = <String>{};
      for (final doc in snap.docs) {
        final title = (doc.data()['title'] ?? '').toString();
        final titleLower = title.toLowerCase();
        if (titleLower.contains(q) && seen.add(titleLower)) {
          serviceMatches.add(
            _SearchSuggestion(label: title, icon: Icons.home_repair_service),
          );
        }
        if (serviceMatches.length >= 5) break;
      }

      _suggestions = [...catMatches, ...serviceMatches];
    } catch (_) {
      _suggestions = catMatches;
    }
    if (mounted) setState(() => _isLoading = false);
    if (_focusNode.hasFocus) _showOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    if (_suggestions.isEmpty && !_isLoading) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              color: isDark ? Colors.grey[900] : Colors.white,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (_, i) {
                            final s = _suggestions[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                s.icon,
                                size: 20,
                                color: s.isCategory
                                    ? DesignTokens.brandPrimary
                                    : Colors.grey[600],
                              ),
                              title: Text(s.label),
                              trailing: s.isCategory
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: DesignTokens.brandPrimary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Category',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: DesignTokens.brandPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                _removeOverlay();
                                _focusNode.unfocus();
                                widget.onSuggestionTap(s);
                              },
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: (value) {
          widget.onChanged(value);
          _updateSuggestions(value);
        },
        decoration: InputDecoration(
          hintText: 'Search services or categories...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          suffixIcon: widget.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.onClear();
                    _removeOverlay();
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? Colors.grey[850] : DesignTokens.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
