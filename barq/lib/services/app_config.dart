class AppConfig {
  AppConfig._();

  static const String pocketBaseUrl = String.fromEnvironment(
    'POCKETBASE_URL',
    defaultValue: 'https://api.barq-api.uk',
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

  static const String openRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );

  static const String openRouterModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    defaultValue: 'openrouter/auto',
  );

  static const String openRouterBaseUrl = String.fromEnvironment(
    'OPENROUTER_BASE_URL',
    defaultValue: 'https://openrouter.ai/api/v1',
  );

  static const String googleMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
    defaultValue: '',
  );

  static const String googleMapsBaseUrl = String.fromEnvironment(
    'GOOGLE_MAPS_BASE_URL',
    defaultValue: 'https://maps.googleapis.com',
  );

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static const String geminiBaseUrl = String.fromEnvironment(
    'GEMINI_BASE_URL',
    defaultValue: 'https://generativelanguage.googleapis.com',
  );

  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static const String groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'llama-3.1-8b-instant',
  );

  static const String groqBaseUrl = String.fromEnvironment(
    'GROQ_BASE_URL',
    defaultValue: 'https://api.groq.com/openai/v1',
  );

  static const String publicApiPlaceholder = 'https://api.barq-api.uk';

  static String get normalizedPocketBaseUrl =>
      _stripTrailingSlash(pocketBaseUrl);
  static String get normalizedGeocodingBaseUrl =>
      _stripTrailingSlash(geocodingBaseUrl);
  static String get normalizedRoutingBaseUrl =>
      _stripTrailingSlash(routingBaseUrl);
  static String get normalizedOpenRouterBaseUrl =>
      _stripTrailingSlash(openRouterBaseUrl);
  static String get normalizedGeminiBaseUrl =>
      _stripTrailingSlash(geminiBaseUrl);
  static String get normalizedGroqBaseUrl => _stripTrailingSlash(groqBaseUrl);
  static String get normalizedGoogleMapsBaseUrl =>
      _stripTrailingSlash(googleMapsBaseUrl);
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
