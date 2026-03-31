import 'package:geolocator/geolocator.dart';

import '../models/place_result.dart';
import 'bahrain_map_service.dart';

class LocationServiceDisabledException implements Exception {}

class LocationPermissionDeniedException implements Exception {}

class LocationPermissionDeniedForeverException implements Exception {}

class LocationService {
  LocationService._();

  static Future<LocationPermission> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationPermissionDeniedException();
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedForeverException();
    }

    return permission;
  }

  static Future<PlaceResult> getCurrentPlace() async {
    await ensurePermission();

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );

    final reverse = await BahrainMapService.reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (reverse != null) {
      return reverse;
    }

    return PlaceResult(
      title: 'Current Location',
      subtitle:
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  static Future<PlaceResult?> tryGetCurrentPlaceSilently() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return null;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );

    final reverse = await BahrainMapService.reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (reverse != null) {
      return reverse;
    }

    return PlaceResult(
      title: 'Current Location',
      subtitle:
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
