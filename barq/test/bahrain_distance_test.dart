import 'package:barq/services/bahrain_map_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zero distance for identical points', () {
    expect(BahrainMapService.distanceMeters(26.06, 50.55, 26.06, 50.55),
        closeTo(0, 0.01));
  });

  test('Seef to Sitra is roughly 12 km', () {
    // Seef district approx 26.241, 50.578; Sitra approx 26.149, 50.620.
    final meters = BahrainMapService.distanceMeters(
        26.241, 50.578, 26.149, 50.620);
    expect(meters, greaterThan(8000));
    expect(meters, lessThan(15000));
  });

  test('150 m auto-complete radius — caller within radius', () {
    // ~120 m apart at Bahrain latitude.
    final meters =
        BahrainMapService.distanceMeters(26.0667, 50.5577, 26.0678, 50.5577);
    expect(meters, lessThan(150));
  });
}
