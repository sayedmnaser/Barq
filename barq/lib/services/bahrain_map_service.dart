import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/place_result.dart';
import 'app_config.dart';

class RouteInfo {
  const RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
}

class BahrainMapService {
  BahrainMapService._();

  static const LatLng bahrainCenter = LatLng(26.0667, 50.5577);
  static const String _userAgent = 'BarqTowApp/1.0';

  static final Map<String, List<PlaceResult>> _searchCache =
      <String, List<PlaceResult>>{};
  static final Map<String, PlaceResult?> _geocodeCache =
      <String, PlaceResult?>{};
  static final Map<String, PlaceResult?> _reverseGeocodeCache =
      <String, PlaceResult?>{};

  static Future<List<PlaceResult>> searchPlaces(
    String query, {
    int limit = 8,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const <PlaceResult>[];
    }

    final cacheKey = '${normalized.toLowerCase()}::$limit';
    final cached = _searchCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final uri =
        Uri.parse('${AppConfig.normalizedGeocodingBaseUrl}/search').replace(
      queryParameters: <String, String>{
        'q': normalized,
        'countrycodes': 'bh',
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '$limit',
      },
    );

    final response = await http.get(
      uri,
      headers: const <String, String>{
        'User-Agent': _userAgent,
        'Accept': 'application/json',
        'Accept-Language': 'en,ar',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Bahrain location search failed (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;
    final results = decoded
        .whereType<Map<String, dynamic>>()
        .map(PlaceResult.fromNominatim)
        .where((place) => place.title.isNotEmpty)
        .toList(growable: false);

    _searchCache[cacheKey] = results;
    return results;
  }

  static Future<PlaceResult?> geocode(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final cacheKey = normalized.toLowerCase();
    if (_geocodeCache.containsKey(cacheKey)) {
      return _geocodeCache[cacheKey];
    }

    try {
      final results = await searchPlaces(normalized, limit: 1);
      final place = results.isEmpty ? null : results.first;
      _geocodeCache[cacheKey] = place;
      return place;
    } catch (_) {
      _geocodeCache[cacheKey] = null;
      return null;
    }
  }

  static Future<PlaceResult?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    if (_reverseGeocodeCache.containsKey(cacheKey)) {
      return _reverseGeocodeCache[cacheKey];
    }

    final uri =
        Uri.parse('${AppConfig.normalizedGeocodingBaseUrl}/reverse').replace(
      queryParameters: <String, String>{
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const <String, String>{
          'User-Agent': _userAgent,
          'Accept': 'application/json',
          'Accept-Language': 'en,ar',
        },
      );

      if (response.statusCode != 200) {
        _reverseGeocodeCache[cacheKey] = null;
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final place = PlaceResult.fromNominatim(decoded);
      final normalizedPlace = place.copyWith(
        title: place.title.trim().isEmpty ? 'Current Location' : place.title,
      );
      _reverseGeocodeCache[cacheKey] = normalizedPlace;
      return normalizedPlace;
    } catch (_) {
      _reverseGeocodeCache[cacheKey] = null;
      return null;
    }
  }

  static Future<RouteInfo> buildRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.normalizedRoutingBaseUrl}/route/v1/driving/'
      '${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
    ).replace(
      queryParameters: const <String, String>{
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: const <String, String>{
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final routes =
            (decoded['routes'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);

        if (routes.isNotEmpty) {
          final firstRoute = routes.first;
          final geometry =
              (firstRoute['geometry'] as Map<String, dynamic>? ?? const {});
          final coordinates =
              (geometry['coordinates'] as List<dynamic>? ?? const <dynamic>[])
                  .whereType<List<dynamic>>()
                  .toList(growable: false);

          final points = coordinates
              .where((pair) => pair.length >= 2)
              .map(
                (pair) => LatLng(
                  (pair[1] as num).toDouble(),
                  (pair[0] as num).toDouble(),
                ),
              )
              .toList(growable: false);

          final distanceKm =
              ((firstRoute['distance'] as num?)?.toDouble() ?? 0) / 1000.0;
          final durationMinutes =
              (((firstRoute['duration'] as num?)?.toDouble() ?? 0) / 60.0)
                  .round();
          final boundedDurationMinutes = durationMinutes.clamp(1, 240).toInt();

          if (points.length >= 2 && distanceKm > 0) {
            return RouteInfo(
              points: points,
              distanceKm: distanceKm,
              durationMinutes: boundedDurationMinutes,
            );
          }
        }
      }
    } catch (_) {
      // Fall back to straight line if routing fails.
    }

    return _fallbackRoute(start: start, end: end);
  }

  static RouteInfo _fallbackRoute({
    required LatLng start,
    required LatLng end,
  }) {
    final distanceKm = _haversineKm(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    final durationMinutes =
        ((distanceKm / 35.0) * 60.0).round().clamp(4, 180).toInt();

    return RouteInfo(
      points: <LatLng>[start, end],
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = _sinSquared(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            _sinSquared(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double degrees) => degrees * 0.017453292519943295;

  static double _sinSquared(double radians) {
    final value = math.sin(radians);
    return value * value;
  }
}
