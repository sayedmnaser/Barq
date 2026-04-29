import 'package:pocketbase/pocketbase.dart';

class TowRequest {
  const TowRequest({
    required this.id,
    required this.userId,
    required this.pickupLocation,
    required this.destination,
    required this.vehicleType,
    required this.details,
    required this.serviceTiming,
    required this.status,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.driverLat,
    this.driverLng,
    this.driverName,
    this.driverUserId,
    this.driverPhone,
    this.driverRating,
    this.driverTotalRides,
    this.licensePlate,
    this.distanceKm,
    this.etaMinutes,
    this.baseFare,
    this.distanceFare,
    this.rated = false,
    this.pickupPhoto,
    this.dropoffPhoto,
    this.damagePhotos = const <String>[],
    required this.created,
    required this.updated,
  });

  final String id;
  final String userId;
  final String pickupLocation;
  final String destination;
  final String vehicleType;
  final String details;
  final String serviceTiming;
  final String status;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? driverLat;
  final double? driverLng;
  final String? driverName;
  final String? driverUserId;
  final String? driverPhone;
  final double? driverRating;
  final int? driverTotalRides;
  final String? licensePlate;
  final double? distanceKm;
  final int? etaMinutes;
  final double? baseFare;
  final double? distanceFare;
  final bool rated;
  final String? pickupPhoto;
  final String? dropoffPhoto;
  final List<String> damagePhotos;
  final DateTime created;
  final DateTime updated;

  double get totalFare => (baseFare ?? 0) + (distanceFare ?? 0);

  bool get isActive =>
      status == 'pending' || status == 'assigned' || status == 'en_route';

  factory TowRequest.fromRecord(RecordModel record) {
    return TowRequest(
      id: record.id,
      userId: record.getStringValue('user'),
      pickupLocation: record.getStringValue('pickup_location'),
      destination: record.getStringValue('destination'),
      vehicleType: record.getStringValue('vehicle_type'),
      details: record.getStringValue('details'),
      serviceTiming: record.getStringValue('service_timing'),
      status: record.getStringValue('status'),
      pickupLat: _nullableDouble(record, 'pickup_lat'),
      pickupLng: _nullableDouble(record, 'pickup_lng'),
      destinationLat: _nullableDouble(record, 'destination_lat'),
      destinationLng: _nullableDouble(record, 'destination_lng'),
      driverLat: _nullableDouble(record, 'driver_lat'),
      driverLng: _nullableDouble(record, 'driver_lng'),
      driverName: _nullableString(record.getStringValue('driver_name')),
      driverUserId: _nullableString(record.getStringValue('driver')),
      driverPhone: _nullableString(record.getStringValue('driver_phone')),
      driverRating: _nullableDouble(record, 'driver_rating'),
      driverTotalRides: _nullableInt(record, 'driver_total_rides'),
      licensePlate: _nullableString(record.getStringValue('license_plate')),
      distanceKm: _nullableDouble(record, 'distance_km'),
      etaMinutes: _nullableInt(record, 'eta_minutes'),
      baseFare: _nullableDouble(record, 'base_fare'),
      distanceFare: _nullableDouble(record, 'distance_fare'),
      rated: record.getBoolValue('rated'),
      pickupPhoto:
          _nullableString(record.getStringValue('pickup_photo')),
      dropoffPhoto:
          _nullableString(record.getStringValue('dropoff_photo')),
      damagePhotos:
          List<String>.from(record.getListValue<String>('damage_photos')),
      created: DateTime.tryParse(record.getStringValue('created')) ??
          DateTime.now(),
      updated: DateTime.tryParse(record.getStringValue('updated')) ??
          DateTime.now(),
    );
  }

  static String? _nullableString(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static double? _nullableDouble(RecordModel record, String field) {
    final value = record.getDoubleValue(field);
    return value == 0 ? null : value;
  }

  static int? _nullableInt(RecordModel record, String field) {
    final value = record.getIntValue(field);
    return value == 0 ? null : value;
  }
}
