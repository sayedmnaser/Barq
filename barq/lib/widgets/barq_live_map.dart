import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/place_result.dart';
import '../services/app_config.dart';
import '../services/bahrain_map_service.dart';

class BarqLiveMap extends StatefulWidget {
  const BarqLiveMap({
    super.key,
    required this.height,
    this.pickup,
    this.destination,
    this.driver,
    this.nearbyDrivers = const <PlaceResult>[],
    this.routePoints = const <LatLng>[],
    this.headline,
    this.subline,
    this.followDriver = true,
  });

  final double height;
  final PlaceResult? pickup;
  final PlaceResult? destination;
  final PlaceResult? driver;
  final List<PlaceResult> nearbyDrivers;
  final List<LatLng> routePoints;
  final String? headline;
  final String? subline;
  final bool followDriver;

  @override
  State<BarqLiveMap> createState() => _BarqLiveMapState();
}

class _BarqLiveMapState extends State<BarqLiveMap>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _driverController;
  LatLng? _displayedDriver;
  LatLng? _previousDriver;
  bool _followDriver = true;
  bool _initialFitDone = false;

  @override
  void initState() {
    super.initState();
    _followDriver = widget.followDriver;
    _displayedDriver = widget.driver?.latLng;
    _driverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(_onMarkerTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitInitial());
  }

  @override
  void didUpdateWidget(covariant BarqLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDriver = widget.driver?.latLng;
    final oldDriver = oldWidget.driver?.latLng;
    if (newDriver != null &&
        (oldDriver == null ||
            oldDriver.latitude != newDriver.latitude ||
            oldDriver.longitude != newDriver.longitude)) {
      _previousDriver = _displayedDriver ?? oldDriver ?? newDriver;
      _driverController
        ..reset()
        ..forward();
      if (_followDriver) {
        _animateCameraTo(newDriver);
      }
    } else if (newDriver == null) {
      _displayedDriver = null;
    }

    final pickupChanged = widget.pickup?.latLng != oldWidget.pickup?.latLng;
    final destChanged =
        widget.destination?.latLng != oldWidget.destination?.latLng;
    if ((pickupChanged || destChanged) && !_initialFitDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitInitial());
    }
  }

  void _onMarkerTick() {
    final start = _previousDriver;
    final end = widget.driver?.latLng;
    if (start == null || end == null) return;
    final t = Curves.easeOutCubic.transform(_driverController.value);
    setState(() {
      _displayedDriver = LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      );
    });
  }

  void _animateCameraTo(LatLng target) {
    final currentZoom = _mapController.camera.zoom;
    final zoom = currentZoom < 13.5 ? 14.5 : currentZoom;
    try {
      _mapController.move(target, zoom);
    } catch (_) {
      // controller may not be ready in the same frame
    }
  }

  void _fitInitial() {
    final coords = _allCoordinates();
    if (coords.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: coords,
          padding: const EdgeInsets.all(48),
          maxZoom: 15,
        ),
      );
      _initialFitDone = true;
    } catch (_) {
      // if controller is not yet attached we'll retry on next update
    }
  }

  void _recenter() {
    final coords = _allCoordinates();
    if (coords.isEmpty) return;
    try {
      if (coords.length == 1) {
        _mapController.move(coords.first, 14.5);
      } else {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: coords,
            padding: const EdgeInsets.all(48),
            maxZoom: 15,
          ),
        );
      }
    } catch (_) {}
    setState(() => _followDriver = true);
  }

  List<LatLng> _allCoordinates() {
    final list = <LatLng>[
      ...widget.routePoints,
      if (widget.pickup != null) widget.pickup!.latLng,
      if (widget.destination != null) widget.destination!.latLng,
      ...widget.nearbyDrivers.map((item) => item.latLng),
      if (widget.driver != null) widget.driver!.latLng,
    ];
    final unique = <LatLng>[];
    for (final p in list) {
      if (!unique.any((u) =>
          u.latitude == p.latitude && u.longitude == p.longitude)) {
        unique.add(p);
      }
    }
    return unique;
  }

  @override
  void dispose() {
    _driverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coords = _allCoordinates();
    final initialCenter =
        coords.isNotEmpty ? coords.first : BahrainMapService.bahrainCenter;
    final initialFit = coords.length > 1
        ? CameraFit.coordinates(
            coordinates: coords,
            padding: const EdgeInsets.all(48),
            maxZoom: 15,
          )
        : null;
    final driverPoint = _displayedDriver ?? widget.driver?.latLng;

    final markers = <Marker>[
      if (widget.pickup != null)
        Marker(
          point: widget.pickup!.latLng,
          width: 54,
          height: 62,
          alignment: Alignment.topCenter,
          child: const _MapMarker(
            icon: Icons.location_on,
            color: Color(0xFF16A34A),
          ),
        ),
      if (widget.destination != null)
        Marker(
          point: widget.destination!.latLng,
          width: 54,
          height: 62,
          alignment: Alignment.topCenter,
          child: const _MapMarker(
            icon: Icons.flag,
            color: Color(0xFFDC2626),
          ),
        ),
      if (driverPoint != null)
        Marker(
          point: driverPoint,
          width: 72,
          height: 72,
          alignment: Alignment.center,
          child: const _PulseMarker(
            color: Color(0xFFF59E0B),
            icon: Icons.local_shipping,
          ),
        ),
      ...widget.nearbyDrivers
          .where(
            (item) =>
                widget.driver == null ||
                item.latitude != widget.driver!.latitude ||
                item.longitude != widget.driver!.longitude,
          )
          .map(
            (item) => Marker(
              point: item.latLng,
              width: 50,
              height: 50,
              alignment: Alignment.center,
              child: const _MapMarker(
                icon: Icons.local_shipping_outlined,
                color: Color(0xFF2563EB),
                compact: true,
              ),
            ),
          ),
    ];

    return Container(
      height: widget.height,
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
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: coords.length > 1 ? 12.0 : 13.4,
              initialCameraFit: initialFit,
              minZoom: 9,
              maxZoom: 18,
              onPointerDown: (_, __) {
                if (_followDriver) setState(() => _followDriver = false);
              },
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
              if (widget.routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.routePoints,
                      strokeWidth: 5,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),
          if ((widget.headline ?? '').isNotEmpty ||
              (widget.subline ?? '').isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.60)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((widget.headline ?? '').isNotEmpty)
                      Text(
                        widget.headline!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                      ),
                    if ((widget.subline ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subline!,
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
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'barq_live_map_recenter_${widget.key}',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF111827),
              onPressed: _recenter,
              child: Icon(
                _followDriver ? Icons.gps_fixed : Icons.gps_not_fixed,
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
                '(c) OpenStreetMap contributors',
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

class _PulseMarker extends StatefulWidget {
  const _PulseMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  State<_PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<_PulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final scale = 0.6 + (t * 1.4);
        final opacity = (1 - t).clamp(0.0, 1.0) * 0.55;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 22),
            ),
          ],
        );
      },
    );
  }
}
