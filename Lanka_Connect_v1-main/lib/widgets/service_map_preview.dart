import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

class ServiceMapPreview extends StatelessWidget {
  const ServiceMapPreview({
    super.key,
    required this.point,
    this.title = '',
    this.height = 180,
    this.onTap,
  });

  final LatLng point;
  final String title;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gmPoint = gm.LatLng(point.latitude, point.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            SizedBox(
              height: height,
              child: AbsorbPointer(
                child: gm.GoogleMap(
                  initialCameraPosition: gm.CameraPosition(
                    target: gmPoint,
                    zoom: 14,
                  ),
                  markers: {
                    gm.Marker(
                      markerId: const gm.MarkerId('preview'),
                      position: gmPoint,
                      infoWindow: gm.InfoWindow(title: title),
                    ),
                  },
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  myLocationButtonEnabled: false,
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap to open full map',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
