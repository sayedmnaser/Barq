import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_rate_limiter.dart';
import 'app_config.dart';

class ReportVerdict {
  const ReportVerdict({
    required this.action,
    required this.confidence,
    required this.reasoning,
  });

  final String action; // dismiss | warn | suspend | escalate
  final double confidence;
  final String reasoning;
}

class CancellationVerdict {
  const CancellationVerdict({
    required this.decision,
    required this.confidence,
    required this.reasoning,
  });

  final String decision; // approved | rejected | needs_review
  final double confidence;
  final String reasoning;
}

class ApplicationVerdict {
  const ApplicationVerdict({
    required this.decision,
    required this.confidence,
    required this.reasoning,
  });

  final String decision; // approved | rejected | needs_review
  final double confidence;
  final String reasoning;
}

class ModerationAiService {
  ModerationAiService._();
  static final ModerationAiService instance = ModerationAiService._();

  Future<ReportVerdict> reviewDriverReport({
    required String category,
    required String description,
    List<String> photoUrls = const <String>[],
  }) async {
    final prompt = '''
You moderate driver reports for a ride/tow app in Bahrain. Decide one action.
Allowed actions:
- "dismiss": low/no evidence, vague, abusive reporter
- "warn": minor first-time issue
- "suspend": serious safety/fraud/repeated misconduct, evidence credible
- "escalate": needs human admin (legal, injury, criminal)

Return STRICT JSON only:
{"action":"...","confidence":0.0-1.0,"reasoning":"short"}

Report category: $category
Description: ${description.trim()}
Attached photos: ${photoUrls.isEmpty ? 'none' : photoUrls.length}
''';

    final raw = await _callGemini(prompt: prompt, imageUrls: photoUrls);
    return _parseReportVerdict(raw);
  }

  Future<CancellationVerdict> reviewDriverCancellation({
    required String reason,
    required String pickupLocation,
    required String destination,
    required String currentStatus,
  }) async {
    final prompt = '''
You moderate driver-initiated cancellations for a tow service in Bahrain.
Decide if the driver should be allowed to cancel.

Allowed decisions:
- "approved": legitimate reason (vehicle breakdown, accident on the way, customer no-show after waiting, unsafe situation, route blocked)
- "rejected": weak/abusive reason (unwilling to drive, found a better fare, dislikes customer, vague excuses)
- "needs_review": ambiguous, needs human admin

Return STRICT JSON only:
{"decision":"...","confidence":0.0-1.0,"reasoning":"short"}

Current status: $currentStatus
Pickup: $pickupLocation
Destination: $destination
Driver reason: ${reason.trim()}
''';

    final raw = await _callGemini(prompt: prompt);
    return _parseCancellationVerdict(raw);
  }

  Future<ApplicationVerdict> reviewDriverApplication({
    required String fullName,
    required String plateNumber,
    required String licenseFrontUrl,
    required String licenseBackUrl,
    required String nationalIdUrl,
    required String carPhotoUrl,
  }) async {
    final prompt = '''
You verify driver applications for a Bahrain ride/tow app. Inspect submitted images.
Check:
- License front: a valid-looking driving license, name readable, photo of person, not expired-looking
- License back: matching plate/details
- National ID: matches name "$fullName"
- Car photo: real vehicle, plate "$plateNumber" visible if possible
- All images clear, not blurry, not screenshots, not obviously forged

Decision rules:
- "approved": all 4 images clearly valid, plausible match
- "rejected": missing info, fake/screenshot, mismatched name/plate, expired
- "needs_review": ambiguous, partially obscured

Return STRICT JSON only:
{"decision":"...","confidence":0.0-1.0,"reasoning":"short"}

Applicant name: $fullName
Plate: $plateNumber
''';

    final raw = await _callGemini(
      prompt: prompt,
      imageUrls: <String>[
        licenseFrontUrl,
        licenseBackUrl,
        nationalIdUrl,
        carPhotoUrl,
      ],
    );
    return _parseApplicationVerdict(raw);
  }

  Future<String> _callGemini({
    required String prompt,
    List<String> imageUrls = const <String>[],
  }) async {
    final apiKey = AppConfig.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY missing');
    }
    if (!AiRateLimiter.instance.tryConsume('moderation')) {
      throw StateError('AI moderation rate limit reached; retry shortly.');
    }

    final parts = <Map<String, dynamic>>[
      <String, dynamic>{'text': prompt},
    ];

    for (final url in imageUrls) {
      final inline = await _fetchAsInlineImage(url);
      if (inline != null) parts.add(inline);
    }

    final base = AppConfig.normalizedGeminiBaseUrl;
    final model = AppConfig.geminiModel;
    final uri = Uri.parse(
      '$base/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final body = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{'role': 'user', 'parts': parts},
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      },
    };

    final response = await http
        .post(
          uri,
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Gemini ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = (decoded['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) return '';
    final content = candidates.first as Map<String, dynamic>;
    final partsOut = (content['content']?['parts'] as List?) ?? const [];
    final buffer = StringBuffer();
    for (final p in partsOut) {
      final text = (p as Map<String, dynamic>)['text'];
      if (text is String) buffer.write(text);
    }
    return buffer.toString();
  }

  Future<Map<String, dynamic>?> _fetchAsInlineImage(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 20),
          );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final mime = res.headers['content-type']?.split(';').first.trim();
      final mimeType =
          (mime != null && mime.startsWith('image/')) ? mime : 'image/jpeg';
      return <String, dynamic>{
        'inlineData': <String, dynamic>{
          'mimeType': mimeType,
          'data': base64Encode(res.bodyBytes),
        },
      };
    } catch (e) {
      debugPrint('moderation: image fetch failed $url: $e');
      return null;
    }
  }

  ReportVerdict _parseReportVerdict(String raw) {
    final json = _safeJson(raw);
    final action = (json['action'] as String?)?.trim().toLowerCase() ?? '';
    final allowed = {'dismiss', 'warn', 'suspend', 'escalate'};
    final safeAction = allowed.contains(action) ? action : 'escalate';
    return ReportVerdict(
      action: safeAction,
      confidence: _readDouble(json['confidence']),
      reasoning:
          (json['reasoning'] as String?)?.trim() ?? 'No reasoning supplied.',
    );
  }

  CancellationVerdict _parseCancellationVerdict(String raw) {
    final json = _safeJson(raw);
    final decision = (json['decision'] as String?)?.trim().toLowerCase() ?? '';
    const allowed = {'approved', 'rejected', 'needs_review'};
    final safe = allowed.contains(decision) ? decision : 'needs_review';
    return CancellationVerdict(
      decision: safe,
      confidence: _readDouble(json['confidence']),
      reasoning:
          (json['reasoning'] as String?)?.trim() ?? 'No reasoning supplied.',
    );
  }

  ApplicationVerdict _parseApplicationVerdict(String raw) {
    final json = _safeJson(raw);
    final decision = (json['decision'] as String?)?.trim().toLowerCase() ?? '';
    final allowed = {'approved', 'rejected', 'needs_review'};
    final safe = allowed.contains(decision) ? decision : 'needs_review';
    return ApplicationVerdict(
      decision: safe,
      confidence: _readDouble(json['confidence']),
      reasoning:
          (json['reasoning'] as String?)?.trim() ?? 'No reasoning supplied.',
    );
  }

  Map<String, dynamic> _safeJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // LLM responses occasionally wrap JSON in prose; fall through to the
      // regex extraction below before giving up.
    }

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(trimmed);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(0)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Final fallback: caller treats empty map as "AI verdict unavailable".
      }
    }
    return const <String, dynamic>{};
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble().clamp(0, 1);
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed.clamp(0, 1);
    }
    return 0.5;
  }
}
