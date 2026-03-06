import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import 'service_detail_screen.dart';

class ServiceMapItem {
  const ServiceMapItem({
    required this.serviceId,
    required this.title,
    required this.locationLabel,
    required this.priceLabel,
    required this.point,
    this.isApproximate = false,
    this.pointSource,
    this.category,
    this.providerId,
  });

  final String serviceId;
  final String title;
  final String locationLabel;
  final String priceLabel;
  final LatLng point;
  final bool isApproximate;
  final String? pointSource;
  final String? category;
  final String? providerId;
}

class ServiceMapScreen extends StatefulWidget {
  const ServiceMapScreen({super.key, required this.items, this.initialCenter});

  final List<ServiceMapItem> items;
  final LatLng? initialCenter;

  @override
  State<ServiceMapScreen> createState() => _ServiceMapScreenState();
}

class _ServiceMapScreenState extends State<ServiceMapScreen> {
  int _selectedIndex = 0;
  LatLng? _userLocation;
  bool _loadingLocation = true;
  bool _mapReady = false;
  gm.GoogleMapController? _mapController;

  gm.LatLng _toGm(LatLng p) => gm.LatLng(p.latitude, p.longitude);

  Set<gm.Marker> _buildMarkers() {
    return {
      for (var i = 0; i < widget.items.length; i++)
        gm.Marker(
          markerId: gm.MarkerId(widget.items[i].serviceId),
          position: _toGm(widget.items[i].point),
          icon: gm.BitmapDescriptor.defaultMarkerWithHue(
            i == _selectedIndex
                ? gm.BitmapDescriptor.hueRed
                : gm.BitmapDescriptor.hueAzure,
          ),
          infoWindow: gm.InfoWindow(title: widget.items[i].title),
          onTap: () {
            setState(() => _selectedIndex = i);
            _mapController?.animateCamera(
              gm.CameraUpdate.newLatLngZoom(_toGm(widget.items[i].point), 14),
            );
          },
        ),
    };
  }

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _loadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _loadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
      });
    } catch (e) {
      debugPrint('Map location detection error: $e');
      setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      if (kIsWeb) {
        return const WebPageScaffold(
          title: 'Service Map',
          subtitle: 'Map view of services by location data.',
          useScaffold: true,
          child: Center(
            child: Text(
              'No mappable locations found. Add city/district or coordinates to view services on map.',
            ),
          ),
        );
      }
      return const MobilePageScaffold(
        title: 'Service Map',
        subtitle: 'Map view of services by location data.',
        accentColor: MobileTokens.primary,
        useScaffold: true,
        body: Center(
          child: Text(
            'No mappable locations found. Add city/district or coordinates to view services on map.',
          ),
        ),
      );
    }

    final selected = widget.items[_selectedIndex];
    final center = widget.initialCenter ?? _userLocation ?? selected.point;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final body = isWide
        ? Row(
            children: [
              Expanded(child: _mapPanel(center)),
              SizedBox(width: 360, child: _listPanel()),
            ],
          )
        : Column(
            children: [
              Expanded(flex: 3, child: _mapPanel(center)),
              Expanded(flex: 2, child: _listPanel()),
            ],
          );

    if (kIsWeb) {
      return WebPageScaffold(
        title: 'Nearby Service Providers',
        subtitle:
            'Map view of service providers near you. Tap a pin to see details.',
        useScaffold: true,
        child: body,
      );
    }

    return MobilePageScaffold(
      title: 'Nearby Service Providers',
      subtitle: 'Map view of service providers near you.',
      accentColor: MobileTokens.primary,
      useScaffold: true,
      actions: [
        if (_userLocation != null)
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            tooltip: 'Center on my location',
            onPressed: () {
              _mapController?.animateCamera(
                gm.CameraUpdate.newLatLngZoom(_toGm(_userLocation!), 13),
              );
            },
          ),
      ],
      body: body,
    );
  }

  Widget _mapPanel(LatLng center) {
    return Stack(
      children: [
        gm.GoogleMap(
          initialCameraPosition: gm.CameraPosition(
            target: _toGm(center),
            zoom: 11,
          ),
          onMapCreated: (controller) {
            setState(() {
              _mapController = controller;
              _mapReady = true;
            });
          },
          markers: _buildMarkers(),
          myLocationEnabled: _userLocation != null,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
        if (!_mapReady)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              alignment: Alignment.center,
              child: const Text('Loading map...'),
            ),
          ),
      ],
    );
  }

  Widget _listPanel() {
    return Column(
      children: [
        if (_loadingLocation)
          const LinearProgressIndicator()
        else if (_userLocation != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 16, color: Colors.indigo),
                const SizedBox(width: 6),
                const Text('Showing nearby providers'),
                const Spacer(),
                Text(
                  '${widget.items.length} found',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: widget.items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final isSelected = index == _selectedIndex;

              // Calculate distance if user location available
              String distanceStr = '';
              if (_userLocation != null) {
                final distanceKm = const Distance().as(
                  LengthUnit.Kilometer,
                  _userLocation!,
                  item.point,
                );
                distanceStr = '${distanceKm.toStringAsFixed(1)} km away';
              }

              return ListTile(
                selected: isSelected,
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  child: Icon(
                    Icons.location_pin,
                    color: isSelected ? Colors.red : Colors.blue,
                  ),
                ),
                title: Text(item.title),
                subtitle: Text(
                  [
                    item.locationLabel,
                    item.priceLabel,
                    if (item.category != null) item.category!,
                    if (distanceStr.isNotEmpty) distanceStr,
                    if (item.isApproximate)
                      item.pointSource ?? 'Approximate location',
                  ].join(' | '),
                ),
                isThreeLine: true,
                trailing: FilledButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ServiceDetailScreen(serviceId: item.serviceId),
                      ),
                    );
                  },
                ),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  _mapController?.animateCamera(
                    gm.CameraUpdate.newLatLngZoom(_toGm(item.point), 14),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
