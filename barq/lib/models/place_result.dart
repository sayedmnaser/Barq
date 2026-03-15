import 'package:latlong2/latlong.dart';

class PlaceResult {
  const PlaceResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  String get label => subtitle.isEmpty ? title : '$title, $subtitle';

  factory PlaceResult.fromNominatim(Map<String, dynamic> json) {
    final address = (json['address'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final title = _firstNonEmpty(<String?>[
      json['name'] as String?,
      address['road'] as String?,
      address['neighbourhood'] as String?,
      address['suburb'] as String?,
      address['city'] as String?,
      address['town'] as String?,
      address['village'] as String?,
      address['hamlet'] as String?,
      address['amenity'] as String?,
      json['display_name'] as String?,
    ]);

    final subtitleParts = <String>[
      if ((address['suburb'] as String?)?.trim().isNotEmpty ?? false)
        (address['suburb'] as String).trim(),
      if ((address['city'] as String?)?.trim().isNotEmpty ?? false)
        (address['city'] as String).trim(),
      if ((address['state'] as String?)?.trim().isNotEmpty ?? false)
        (address['state'] as String).trim(),
    ];

    final displayName = (json['display_name'] as String?)?.trim() ?? '';
    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.toSet().join(' • ')
        : displayName;

    return PlaceResult(
      title: title.isEmpty ? displayName : title,
      subtitle: subtitle,
      latitude: double.tryParse((json['lat'] ?? '').toString()) ?? 26.0667,
      longitude: double.tryParse((json['lon'] ?? '').toString()) ?? 50.5577,
    );
  }

  PlaceResult copyWith({
    String? title,
    String? subtitle,
    double? latitude,
    double? longitude,
  }) {
    return PlaceResult(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }
}
