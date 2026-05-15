// Single source of truth for fare math. Both estimate and request screens
// must call into here so the price the customer sees and the price they pay
// match. Bahrain is UTC+3 year-round (no DST), so we compute night windows
// against that fixed offset rather than the device's local clock — which
// would misfire for a phone set to a different timezone.
class BahrainPricing {
  static const double nightSurchargeBhd = 5.0;
  static const int _nightStartHour = 22;
  static const int _nightEndHour = 6;
  static const Duration _bahrainOffset = Duration(hours: 3);

  static double tierFareForDistance(double km) {
    if (km <= 0) return 10.0;
    if (km <= 15) return 10.0;
    if (km <= 20) return 15.0;
    return 20.0;
  }

  static bool isNightHourAt(DateTime nowUtc) {
    final bahrain = nowUtc.toUtc().add(_bahrainOffset);
    final hour = bahrain.hour;
    return hour >= _nightStartHour || hour < _nightEndHour;
  }

  static bool isNightHour() => isNightHourAt(DateTime.now().toUtc());

  static FareBreakdown computeFare(double distanceKm, {DateTime? at}) {
    final base = tierFareForDistance(distanceKm);
    final night = at != null ? isNightHourAt(at) : isNightHour();
    final surcharge = night ? nightSurchargeBhd : 0.0;
    return FareBreakdown(
      baseFare: base,
      distanceFare: surcharge,
      total: base + surcharge,
      isNight: night,
    );
  }
}

class FareBreakdown {
  const FareBreakdown({
    required this.baseFare,
    required this.distanceFare,
    required this.total,
    required this.isNight,
  });

  final double baseFare;
  final double distanceFare;
  final double total;
  final bool isNight;
}
