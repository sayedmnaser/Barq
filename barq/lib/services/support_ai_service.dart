import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';

class SupportAiService {
  SupportAiService._();

  static final SupportAiService instance = SupportAiService._();

  Future<String> generateReply({
    required String userMessage,
    required List<Map<String, String>> history,
    required bool isArabic,
  }) async {
    final prompt = isArabic
        ? 'أنت مساعد دعم داخل تطبيق سحب سيارات. أجب بإيجاز وبخطوات عملية واضحة.'
        : 'You are Barq in-app support for towing services only. Answer only app topics like tow requests, drivers, map, pricing, tracking, account, settings, payments, and permissions. If a question is unrelated to the app, politely refuse and redirect to an app-support topic. Keep replies short and actionable.';

    if (!_isAppRelatedMessage(userMessage)) {
      return _offTopicReply(isArabic);
    }

    final groqKey = AppConfig.groqApiKey.trim();
    if (groqKey.isNotEmpty) {
      final groqReply = await _tryGroqReply(
        apiKey: groqKey,
        userMessage: userMessage,
        history: history,
        prompt: prompt,
      );
      if (groqReply != null && groqReply.trim().isNotEmpty) {
        return groqReply.trim();
      }
    }

    final openRouterKey = AppConfig.openRouterApiKey.trim();
    if (openRouterKey.isNotEmpty) {
      final openRouterReply = await _tryOpenRouterReply(
        apiKey: openRouterKey,
        userMessage: userMessage,
        history: history,
        prompt: prompt,
      );
      if (openRouterReply != null && openRouterReply.trim().isNotEmpty) {
        return openRouterReply.trim();
      }
    }

    final geminiKey = AppConfig.geminiApiKey.trim();
    if (geminiKey.isNotEmpty) {
      final geminiReply = await _tryGeminiReply(
        apiKey: geminiKey,
        userMessage: userMessage,
        history: history,
        prompt: prompt,
      );
      if (geminiReply != null && geminiReply.trim().isNotEmpty) {
        return geminiReply.trim();
      }
    }

    return _fallbackReply(userMessage, isArabic);
  }

  Future<String?> _tryOpenRouterReply({
    required String apiKey,
    required String userMessage,
    required List<Map<String, String>> history,
    required String prompt,
  }) async {
    final modelCandidates = _resolveOpenRouterModelCandidates();
    String? lastError;

    final messages = <Map<String, String>>[
      <String, String>{'role': 'system', 'content': prompt},
      ...history.take(8).map(
            (item) => <String, String>{
              'role': item['role'] == 'assistant' ? 'assistant' : 'user',
              'content': item['text'] ?? '',
            },
          ),
      <String, String>{'role': 'user', 'content': userMessage},
    ];

    for (final model in modelCandidates) {
      try {
        final response = await http
            .post(
              Uri.parse(
                '${AppConfig.normalizedOpenRouterBaseUrl}/chat/completions',
              ),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://barq-app.local',
                'X-Title': 'Barq Support Chat',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode(<String, dynamic>{
                'model': model,
                'messages': messages,
                'temperature': 0.35,
                'max_tokens': 260,
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final text = _extractGroqText(decoded);
          if (text.isNotEmpty) {
            return text;
          }
          lastError = 'OpenRouter returned empty content for model "$model".';
          continue;
        }

        lastError =
            'OpenRouter model "$model" failed with ${response.statusCode}: ${_readErrorMessage(response.body)}';
      } catch (e) {
        lastError = 'OpenRouter model "$model" request error: $e';
      }
    }

    if (kDebugMode && lastError != null) {
      debugPrint('[SupportAiService] $lastError');
    }
    return null;
  }

  Future<String?> _tryGroqReply({
    required String apiKey,
    required String userMessage,
    required List<Map<String, String>> history,
    required String prompt,
  }) async {
    final modelCandidates = _resolveGroqModelCandidates();
    String? lastError;

    final messages = <Map<String, String>>[
      <String, String>{'role': 'system', 'content': prompt},
      ...history.take(8).map(
            (item) => <String, String>{
              'role': item['role'] == 'assistant' ? 'assistant' : 'user',
              'content': item['text'] ?? '',
            },
          ),
      <String, String>{'role': 'user', 'content': userMessage},
    ];

    for (final model in modelCandidates) {
      try {
        final response = await http
            .post(
              Uri.parse('${AppConfig.normalizedGroqBaseUrl}/chat/completions'),
              headers: <String, String>{
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'model': model,
                'messages': messages,
                'temperature': 0.35,
                'max_tokens': 260,
              }),
            )
            .timeout(const Duration(seconds: 18));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final text = _extractGroqText(decoded);
          if (text.isNotEmpty) {
            return text;
          }
          lastError = 'Groq returned empty content for model "$model".';
          continue;
        }

        lastError =
            'Groq model "$model" failed with ${response.statusCode}: ${_readErrorMessage(response.body)}';
      } catch (e) {
        lastError = 'Groq model "$model" request error: $e';
      }
    }

    if (kDebugMode && lastError != null) {
      debugPrint('[SupportAiService] $lastError');
    }
    return null;
  }

  Future<String?> _tryGeminiReply({
    required String apiKey,
    required String userMessage,
    required List<Map<String, String>> history,
    required String prompt,
  }) async {
    final contents = <Map<String, dynamic>>[
      ...history.take(8).map(
            (item) => <String, dynamic>{
              'role': item['role'] == 'assistant' ? 'model' : 'user',
              'parts': <Map<String, String>>[
                <String, String>{'text': item['text'] ?? ''}
              ],
            },
          ),
      <String, dynamic>{
        'role': 'user',
        'parts': <Map<String, String>>[
          <String, String>{'text': userMessage}
        ],
      },
    ];

    final modelCandidates = _resolveGeminiModelCandidates();
    String? lastError;

    for (final model in modelCandidates) {
      try {
        final response = await http
            .post(
              Uri.parse(
                '${AppConfig.normalizedGeminiBaseUrl}/v1beta/models/$model:generateContent?key=$apiKey',
              ),
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'system_instruction': <String, dynamic>{
                  'parts': <Map<String, String>>[
                    <String, String>{'text': prompt}
                  ],
                },
                'contents': contents,
                'generationConfig': <String, dynamic>{
                  'temperature': 0.35,
                  'maxOutputTokens': 260,
                },
              }),
            )
            .timeout(const Duration(seconds: 18));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final text = _extractGeminiText(decoded);
          if (text.isNotEmpty) {
            return text;
          }
          lastError = 'Gemini returned empty content for model "$model".';
          continue;
        }

        lastError =
            'Gemini model "$model" failed with ${response.statusCode}: ${_readErrorMessage(response.body)}';
      } catch (e) {
        lastError = 'Gemini model "$model" request error: $e';
      }
    }

    if (kDebugMode && lastError != null) {
      debugPrint('[SupportAiService] $lastError');
    }
    return null;
  }

  List<String> _resolveOpenRouterModelCandidates() {
    final preferred = AppConfig.openRouterModel.trim();
    final options = <String>[
      if (preferred.isNotEmpty) preferred,
      'openrouter/auto',
      'google/gemma-3-4b-it:free',
      'meta-llama/llama-3.3-8b-instruct:free',
      'microsoft/phi-4-reasoning-plus:free',
    ];
    return _dedupe(options);
  }

  List<String> _resolveGroqModelCandidates() {
    final preferred = AppConfig.groqModel.trim();
    final options = <String>[
      if (preferred.isNotEmpty) preferred,
      'llama-3.1-8b-instant',
      'llama-3.3-70b-versatile',
      'qwen/qwen3-32b',
      'groq/compound-mini',
    ];
    return _dedupe(options);
  }

  List<String> _resolveGeminiModelCandidates() {
    final preferred = AppConfig.geminiModel.trim();
    final options = <String>[
      if (preferred.isNotEmpty) preferred,
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash-lite-001',
    ];
    return _dedupe(options);
  }

  List<String> _dedupe(List<String> values) {
    final unique = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty || unique.contains(normalized)) {
        continue;
      }
      unique.add(normalized);
    }
    return unique;
  }

  String _extractGroqText(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }

    for (final choice in choices.whereType<Map<String, dynamic>>()) {
      final message = choice['message'];
      if (message is! Map<String, dynamic>) {
        continue;
      }
      final content = message['content'];
      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }
      if (content is List) {
        for (final part in content.whereType<Map<String, dynamic>>()) {
          final text = part['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text.trim();
          }
        }
      }
    }
    return '';
  }

  String _extractGeminiText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }

    for (final candidate in candidates.whereType<Map<String, dynamic>>()) {
      final content = candidate['content'];
      if (content is! Map<String, dynamic>) {
        continue;
      }
      final parts = content['parts'];
      if (parts is! List) {
        continue;
      }
      for (final part in parts.whereType<Map<String, dynamic>>()) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    }
    return '';
  }

  String _readErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // ignore parse errors
    }
    final trimmed = body.trim();
    return trimmed.length <= 220 ? trimmed : '${trimmed.substring(0, 220)}...';
  }

  bool _isAppRelatedMessage(String message) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty) {
      return true;
    }

    const neutralPhrases = <String>[
      'hi',
      'hello',
      'hey',
      'thanks',
      'thank you',
      'ok',
      'okay',
      'مرحبا',
      'اهلا',
      'شكرا',
    ];
    if (neutralPhrases.contains(text)) {
      return true;
    }

    const appKeywords = <String>[
      'barq',
      'tow',
      'towing',
      'driver',
      'customer',
      'request',
      'service',
      'track',
      'tracking',
      'eta',
      'distance',
      'fare',
      'price',
      'pricing',
      'payment',
      'wallet',
      'map',
      'location',
      'gps',
      'route',
      'pickup',
      'destination',
      'drop',
      'account',
      'login',
      'sign in',
      'signup',
      'sign up',
      'otp',
      'phone',
      'email',
      'settings',
      'language',
      'theme',
      'role',
      'driver panel',
      'support',
      'chat',
      'permission',
      'notification',
      'cancel',
      'assigned',
      'en_route',
      'completed',
      'pocketbase',
      'api',
      'apk',
      'سحب',
      'ونش',
      'قطر',
      'سيارة',
      'سائق',
      'عميل',
      'طلب',
      'خدمة',
      'تتبع',
      'خريطة',
      'موقع',
      'تسعير',
      'سعر',
      'دفع',
      'حساب',
      'تسجيل',
      'دخول',
      'اعدادات',
      'إعدادات',
      'لغة',
      'دعم',
      'برق',
    ];

    return appKeywords.any(text.contains);
  }

  String _offTopicReply(bool isArabic) {
    return isArabic
        ? 'يمكنني المساعدة فقط في مواضيع تطبيق برق مثل الطلبات، السائق، الخريطة، التسعير، الدفع، الحساب، والإعدادات. اكتب مشكلتك داخل التطبيق وسأعطيك خطوات مباشرة.'
        : 'I can only help with Barq app topics (requests, drivers, map, pricing, payments, account, and settings). Please share your app issue and I will give direct steps.';
  }

  String _fallbackReply(String message, bool isArabic) {
    final text = message.toLowerCase();
    if (text.contains('price') ||
        text.contains('cost') ||
        text.contains('fare')) {
      return isArabic
          ? 'تسعير الخريطة حاليًا: حد أدنى 5 د.ب، حد أقصى 20 د.ب نهارًا، وإضافة 5 د.ب ليلًا.'
          : 'Current map pricing: 5 BHD minimum, 20 BHD daytime maximum, plus 5 BHD at night.';
    }
    if (text.contains('driver') || text.contains('closest')) {
      return isArabic
          ? 'افتح صفحة طلب السحب، وسيظهر أقرب 5 سائقين تلقائيًا على الخريطة مع خيار طلب الأقرب.'
          : 'Open Request Tow page to see the nearest 5 drivers on map and request the closest one.';
    }
    if (text.contains('location') || text.contains('gps')) {
      return isArabic
          ? 'تأكد من تفعيل مشاركة الموقع في الإعدادات ومنح إذن الموقع للتطبيق.'
          : 'Please enable Share Location in Settings and grant location permission to the app.';
    }
    return isArabic
        ? 'اكتب المشكلة باختصار (الدفع، السائق، الخريطة، أو تسجيل الدخول) وسأعطيك خطوات مباشرة.'
        : 'Tell me the issue briefly (payment, driver, map, or login) and I will give direct steps.';
  }
}
