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
  static const Map<String, String> _searchAliases = <String, String>{
    '\u0627\u0644\u0631\u0641\u0627\u0639': 'Riffa Bahrain',
    '\u0631\u0641\u0627\u0639': 'Riffa Bahrain',
    '\u0627\u0644\u0645\u062d\u0631\u0642': 'Muharraq Bahrain',
    '\u0645\u062d\u0631\u0642': 'Muharraq Bahrain',
    '\u0627\u0644\u0645\u0646\u0627\u0645\u0629': 'Manama Bahrain',
    '\u0645\u0646\u0627\u0645\u0629': 'Manama Bahrain',
    '\u0633\u062a\u0631\u0629': 'Sitra Bahrain',
    '\u062d\u0645\u062f': 'Hamad Town Bahrain',
    '\u0645\u062f\u064a\u0646\u0629 \u062d\u0645\u062f': 'Hamad Town Bahrain',
    '\u0639\u064a\u0633\u0649': 'Isa Town Bahrain',
    '\u0645\u062f\u064a\u0646\u0629 \u0639\u064a\u0633\u0649':
        'Isa Town Bahrain',
  };

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

    Object? lastError;
    for (final searchQuery in _searchVariants(normalized)) {
      try {
        final results = await _fetchNominatimSearch(searchQuery, limit: limit);
        if (results.isNotEmpty) {
          _searchCache[cacheKey] = results;
          return results;
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    _searchCache[cacheKey] = const <PlaceResult>[];
    return const <PlaceResult>[];
  }

  static Iterable<String> _searchVariants(String query) sync* {
    final normalized = query.trim();
    yield normalized;

    final alias = _searchAliases[normalized];
    if (alias != null) {
      yield alias;
    }

    if (!normalized.toLowerCase().contains('bahrain')) {
      yield '$normalized Bahrain';
    }
  }

  static Future<List<PlaceResult>> _fetchNominatimSearch(
    String query, {
    required int limit,
  }) async {
    final uri =
        Uri.parse('${AppConfig.normalizedGeocodingBaseUrl}/search').replace(
      queryParameters: <String, String>{
        'q': query,
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

    final googleResult = await _googleGeocode(normalized);
    if (googleResult != null) {
      _geocodeCache[cacheKey] = googleResult;
      return googleResult;
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

  static Future<PlaceResult?> _googleGeocode(String query) async {
    final key = AppConfig.googleMapsKey.trim();
    if (key.isEmpty) return null;

    final uri = Uri.parse(
            '${AppConfig.normalizedGoogleMapsBaseUrl}/maps/api/geocode/json')
        .replace(queryParameters: <String, String>{
      'address': query,
      'components': 'country:BH',
      'language': 'en',
      'key': key,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final status = decoded['status'] as String? ?? '';
      if (status != 'OK') return null;
      final results = decoded['results'] as List<dynamic>? ?? const <dynamic>[];
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final formatted = first['formatted_address'] as String? ?? query;
      final geometry = first['geometry'] as Map<String, dynamic>? ?? const {};
      final location =
          geometry['location'] as Map<String, dynamic>? ?? const {};
      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return PlaceResult(
        title: formatted.split(',').first.trim(),
        subtitle: formatted,
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
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
    final google = await _googleDirections(start: start, end: end);
    if (google != null) return google;

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

  static Future<RouteInfo?> _googleDirections({
    required LatLng start,
    required LatLng end,
  }) async {
    final key = AppConfig.googleMapsKey.trim();
    if (key.isEmpty) return null;

    final uri = Uri.parse(
            '${AppConfig.normalizedGoogleMapsBaseUrl}/maps/api/directions/json')
        .replace(queryParameters: <String, String>{
      'origin': '${start.latitude},${start.longitude}',
      'destination': '${end.latitude},${end.longitude}',
      'mode': 'driving',
      'departure_time': 'now',
      'language': 'en',
      'region': 'bh',
      'key': key,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final status = decoded['status'] as String? ?? '';
      if (status != 'OK') return null;
      final routes = decoded['routes'] as List<dynamic>? ?? const <dynamic>[];
      if (routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final overview = route['overview_polyline'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final encoded = overview['points'] as String? ?? '';
      if (encoded.isEmpty) return null;
      final points = _decodePolyline(encoded);
      if (points.length < 2) return null;
      final legs = route['legs'] as List<dynamic>? ?? const <dynamic>[];
      double meters = 0;
      double seconds = 0;
      for (final leg in legs.whereType<Map<String, dynamic>>()) {
        final dist = leg['distance'] as Map<String, dynamic>?;
        meters += (dist?['value'] as num?)?.toDouble() ?? 0;
        final dur = (leg['duration_in_traffic'] as Map<String, dynamic>?) ??
            (leg['duration'] as Map<String, dynamic>?);
        seconds += (dur?['value'] as num?)?.toDouble() ?? 0;
      }
      final distanceKm = meters / 1000.0;
      final durationMinutes = (seconds / 60.0).round().clamp(1, 240).toInt();
      if (distanceKm <= 0) return null;
      return RouteInfo(
        points: points,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Decode Google encoded polyline algorithm format → list of LatLng.
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
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
