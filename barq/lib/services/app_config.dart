class AppConfig {
  AppConfig._();

  static const String pocketBaseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'https://api.barqapp.com',
  );

  static const String geocodingBaseUrl = String.fromEnvironment(
    'GEOCODING_BASE_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );

  static const String routingBaseUrl = String.fromEnvironment(
    'ROUTING_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String mapUserAgent = String.fromEnvironment(
    'MAP_USER_AGENT',
    defaultValue: 'com.barq.app',
  );

  static const String publicApiPlaceholder = 'https://api.barqapp.com';

  static String get normalizedPocketBaseUrl => _stripTrailingSlash(pocketBaseUrl);
  static String get normalizedGeocodingBaseUrl => _stripTrailingSlash(geocodingBaseUrl);
  static String get normalizedRoutingBaseUrl => _stripTrailingSlash(routingBaseUrl);
  static bool get usesPocketBasePlaceholder =>
      normalizedPocketBaseUrl == publicApiPlaceholder;

  static String _stripTrailingSlash(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
