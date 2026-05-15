// Client-side rate limiter for AI provider calls (Gemini / Groq / OpenRouter).
//
// API keys are baked into the APK; without a throttle a misbehaving client or
// abusive user could burn the project's quota in seconds. PocketBase hooks
// cannot intercept these calls because they go direct from device -> Google
// / Groq endpoints. Keeping the limiter in-memory means it resets on app
// restart, which is fine — the goal is to bound steady-state cost, not stop
// a determined attacker (they would need to repackage the APK to bypass).
//
// Limits per category are conservative defaults; tighten or pass overrides if
// a feature is unusually chatty.
import 'dart:collection';

class AiRateLimiter {
  AiRateLimiter._();
  static final AiRateLimiter instance = AiRateLimiter._();

  static const Duration _minute = Duration(minutes: 1);
  static const Duration _hour = Duration(hours: 1);

  final Map<String, Queue<DateTime>> _history = <String, Queue<DateTime>>{};

  bool tryConsume(
    String category, {
    int maxPerMinute = 6,
    int maxPerHour = 30,
  }) {
    final now = DateTime.now();
    final q = _history.putIfAbsent(category, Queue<DateTime>.new);
    while (q.isNotEmpty && now.difference(q.first) > _hour) {
      q.removeFirst();
    }
    int perMinute = 0;
    for (final t in q) {
      if (now.difference(t) <= _minute) perMinute++;
    }
    if (q.length >= maxPerHour) return false;
    if (perMinute >= maxPerMinute) return false;
    q.addLast(now);
    return true;
  }

  Duration cooldownFor(String category) {
    final q = _history[category];
    if (q == null || q.isEmpty) return Duration.zero;
    final oldest = q.first;
    final remain = _hour - DateTime.now().difference(oldest);
    if (remain.isNegative) return Duration.zero;
    return remain;
  }
}
