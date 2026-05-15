import 'package:barq/services/ai_rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('separate categories have independent quotas', () {
    final limiter = AiRateLimiter.instance;
    // Drain "iso_a" using a tiny per-minute cap.
    for (int i = 0; i < 3; i++) {
      expect(
        limiter.tryConsume('iso_a', maxPerMinute: 3, maxPerHour: 10),
        true,
        reason: 'within-budget call $i should succeed',
      );
    }
    expect(
      limiter.tryConsume('iso_a', maxPerMinute: 3, maxPerHour: 10),
      false,
      reason: 'over-budget call rejected',
    );
    expect(
      limiter.tryConsume('iso_b', maxPerMinute: 3, maxPerHour: 10),
      true,
      reason: 'different category is independent',
    );
  });

  test('hour cap rejects past steady-state', () {
    final limiter = AiRateLimiter.instance;
    for (int i = 0; i < 5; i++) {
      expect(
        limiter.tryConsume('hour_cap', maxPerMinute: 10, maxPerHour: 5),
        true,
      );
    }
    expect(
      limiter.tryConsume('hour_cap', maxPerMinute: 10, maxPerHour: 5),
      false,
    );
  });
}
