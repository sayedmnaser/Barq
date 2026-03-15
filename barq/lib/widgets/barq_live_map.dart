import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/place_result.dart';
import '../services/app_config.dart';
import '../services/bahrain_map_service.dart';

class BarqLiveMap extends StatelessWidget {
  const BarqLiveMap({
    super.key,
    required this.height,
    this.pickup,
    this.destination,
    this.driver,
    this.routePoints = const <LatLng>[],
    this.headline,
    this.subline,
  });

  final double height;
  final PlaceResult? pickup;
  final PlaceResult? destination;
  final PlaceResult? driver;
  final List<LatLng> routePoints;
  final String? headline;
  final String? subline;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coordinates = <LatLng>[
      ...routePoints,
      if (pickup != null) pickup!.latLng,
      if (destination != null) destination!.latLng,
      if (driver != null) driver!.latLng,
    ];

    final uniqueCoordinates = <LatLng>[];
    for (final point in coordinates) {
      final exists = uniqueCoordinates.any(
        (item) =>
            item.latitude == point.latitude && item.longitude == point.longitude,
      );
      if (!exists) {
        uniqueCoordinates.add(point);
      }
    }

    final initialCenter =
        uniqueCoordinates.isNotEmpty ? uniqueCoordinates.first : BahrainMapService.bahrainCenter;

    final initialFit = uniqueCoordinates.length > 1
        ? CameraFit.coordinates(
            coordinates: uniqueCoordinates,
            padding: const EdgeInsets.all(36),
            maxZoom: 15,
          )
        : null;

    final markers = <Marker>[
      if (pickup != null)
        Marker(
          point: pickup!.latLng,
          width: 54,
          height: 62,
          alignment: Alignment.topCenter,
          child: const _MapMarker(
            icon: Icons.location_on,
            color: Color(0xFF16A34A),
          ),
        ),
      if (destination != null)
        Marker(
          point: destination!.latLng,
          width: 54,
          height: 62,
          alignment: Alignment.topCenter,
          child: const _MapMarker(
            icon: Icons.flag,
            color: Color(0xFFDC2626),
          ),
        ),
      if (driver != null)
        Marker(
          point: driver!.latLng,
          width: 58,
          height: 58,
          alignment: Alignment.center,
          child: const _MapMarker(
            icon: Icons.local_shipping,
            color: Color(0xFFF59E0B),
            compact: true,
          ),
        ),
    ];

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF27314A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: uniqueCoordinates.length > 1 ? 12.0 : 13.4,
              initialCameraFit: initialFit,
              minZoom: 9,
              maxZoom: 18,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(25.75, 50.35),
                  const LatLng(26.45, 50.85),
                ),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.mapTileUrl,
                userAgentPackageName: AppConfig.mapUserAgent,
              ),
              if (routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),
          if ((headline ?? '').isNotEmpty || (subline ?? '').isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.60)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((headline ?? '').isNotEmpty)
                      Text(
                        headline!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                      ),
                    if ((subline ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subline!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF4B5563),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Positioned(
            left: 10,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.icon,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 48.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: compact ? 20 : 24),
    );
  }
}
