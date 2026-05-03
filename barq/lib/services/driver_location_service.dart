import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import 'pocketbase_service.dart';

/// Keeps pushing the signed-in driver's coordinates to PocketBase so that
/// customer track screens see a live marker even when the driver app is
/// backgrounded or the screen is locked.
///
/// On Android the geolocator foreground-notification config promotes the
/// app process to a foreground service; the OS will not kill it while the
/// notification is visible. On other platforms this falls back to a plain
/// position stream that only ticks while the app is foregrounded.
class DriverLocationService {
  DriverLocationService._();
  static final DriverLocationService instance = DriverLocationService._();

  static const Duration _livePushInterval = Duration(seconds: 5);
  static const Duration _initialFixTimeout = Duration(seconds: 10);

  StreamSubscription<Position>? _subscription;
  bool _starting = false;

  bool get isRunning => _subscription != null;

  Future<void> start() async {
    if (_subscription != null || _starting) return;
    _starting = true;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final settings = _buildSettings();
      unawaited(_pushCurrentPositionOnce());
      _subscription = Geolocator.getPositionStream(locationSettings: settings)
          .listen(_onPosition, onError: (_) {});
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  LocationSettings _buildSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: _livePushInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Barq driver active',
          notificationText: 'Sharing live location with your customer.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  Future<void> _pushCurrentPositionOnce() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _initialFixTimeout,
      );
      await _onPosition(position);
    } catch (_) {
      // The stream below will retry when the next fix arrives.
    }
  }

  Future<void> _onPosition(Position position) async {
    final pb = PocketBaseService.instance;
    if (!pb.isAuthenticated || !pb.isCurrentUserDriver) return;
    final name = pb.currentUserName;
    try {
      await pb.upsertCurrentDriverProfile(
        driverName: name,
        driverLat: position.latitude,
        driverLng: position.longitude,
        isAvailable: true,
      );
    } catch (_) {
      // non-fatal; ride-relevant push is still attempted below
    }
    try {
      await pb.pushDriverLocationToActiveRequests(
        latitude: position.latitude,
        longitude: position.longitude,
        driverName: name,
      );
    } catch (_) {
      // skip this tick; next position will retry
    }
  }
}
