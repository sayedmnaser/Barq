import 'package:barq/services/bahrain_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _bahrainUtcAtHour(int hour) {
  // Bahrain is UTC+3 year-round. To force a specific Bahrain-local hour
  // independent of test-host timezone, subtract the offset from a UTC stamp.
  final base = DateTime.utc(2026, 1, 1, hour - 3);
  return base;
}

void main() {
  group('tier fare', () {
    test('zero or negative km returns minimum 10 BHD', () {
      expect(BahrainPricing.tierFareForDistance(0), 10.0);
      expect(BahrainPricing.tierFareForDistance(-1), 10.0);
    });
    test('short trips up to 15 km cost 10 BHD', () {
      expect(BahrainPricing.tierFareForDistance(0.1), 10.0);
      expect(BahrainPricing.tierFareForDistance(15), 10.0);
    });
    test('15 < km <= 20 cost 15 BHD', () {
      expect(BahrainPricing.tierFareForDistance(15.01), 15.0);
      expect(BahrainPricing.tierFareForDistance(20), 15.0);
    });
    test('km > 20 cost 20 BHD', () {
      expect(BahrainPricing.tierFareForDistance(20.01), 20.0);
      expect(BahrainPricing.tierFareForDistance(100), 20.0);
    });
  });

  group('night window', () {
    test('21:59 Bahrain local is daytime', () {
      expect(BahrainPricing.isNightHourAt(_bahrainUtcAtHour(21)), false);
    });
    test('22:00 Bahrain local enters night', () {
      expect(BahrainPricing.isNightHourAt(_bahrainUtcAtHour(22)), true);
    });
    test('03:00 Bahrain local still night', () {
      expect(BahrainPricing.isNightHourAt(_bahrainUtcAtHour(3)), true);
    });
    test('06:00 Bahrain local exits night', () {
      expect(BahrainPricing.isNightHourAt(_bahrainUtcAtHour(6)), false);
    });
  });

  group('computeFare', () {
    test('day fare 18 km = 15 BHD base, 0 surcharge', () {
      final fare = BahrainPricing.computeFare(18, at: _bahrainUtcAtHour(14));
      expect(fare.baseFare, 15.0);
      expect(fare.distanceFare, 0.0);
      expect(fare.total, 15.0);
      expect(fare.isNight, false);
    });
    test('night fare 25 km = 20 BHD base + 5 BHD surcharge', () {
      final fare = BahrainPricing.computeFare(25, at: _bahrainUtcAtHour(23));
      expect(fare.baseFare, 20.0);
      expect(fare.distanceFare, 5.0);
      expect(fare.total, 25.0);
      expect(fare.isNight, true);
    });
  });
}
