import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pocketbase/pocketbase.dart';

import 'models/place_result.dart';
import 'services/app_preferences_service.dart';
import 'services/bahrain_map_service.dart';
import 'services/location_service.dart';
import 'services/pocketbase_service.dart';
import 'settings.dart';
import 'track_service_page.dart';
import 'widgets/barq_live_map.dart';
import 'widgets/place_search_sheet.dart';

enum TowVehicleKind { sedan, suv, motorcycle, flatbed }

class NearbyDriver {
  const NearbyDriver({
    required this.id,
    required this.name,
    required this.place,
    required this.distanceKm,
    this.rating = 0,
    this.totalRides = 0,
    this.licensePlate,
  });

  final String id;
  final String name;
  final PlaceResult place;
  final double distanceKm;
  final double rating;
  final int totalRides;
  final String? licensePlate;
}

class RequestTowPage extends StatefulWidget {
  const RequestTowPage({super.key, required this.language});

  final AppLanguage language;

  @override
  State<RequestTowPage> createState() => _RequestTowPageState();
}

class _RequestTowPageState extends State<RequestTowPage> {
  static const Distance _distanceCalculator = Distance();

  final PocketBaseService _pocketBaseService = PocketBaseService.instance;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  PlaceResult? _pickupPlace;
  PlaceResult? _destinationPlace;
  RouteInfo? _routeInfo;

  TowVehicleKind _vehicleKind = TowVehicleKind.flatbed;
  int _serviceTiming = 0;
  bool _isLoadingRoute = false;
  bool _isSubmitting = false;
  bool _isFetchingCurrentLocation = false;
  bool _isLoadingNearbyDrivers = false;
  bool _shareLocationEnabled = true;
  String? _routeError;
  List<NearbyDriver> _nearbyDrivers = const <NearbyDriver>[];

  bool get _isArabic => widget.language == AppLanguage.ar;

  @override
  void initState() {
    super.initState();
    _loadLocationPreferences();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationPreferences() async {
    final enabled = await AppPreferencesService.getShareLocationEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _shareLocationEnabled = enabled;
    });
    await _initializePickupFromCache();
  }

  NearbyDriver? get _nearestDriver =>
      _nearbyDrivers.isEmpty ? null : _nearbyDrivers.first;

  Future<void> _initializePickupFromCache() async {
    if (!_shareLocationEnabled) {
      return;
    }

    final cachedPickup = await AppPreferencesService.getLastPickupPlace();
    if (cachedPickup != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pickupPlace = cachedPickup;
        _pickupController.text = cachedPickup.label;
      });
      await _loadNearbyDrivers(userPlace: cachedPickup);
      return;
    }

    try {
      final silentPlace = await LocationService.tryGetCurrentPlaceSilently();
      if (silentPlace == null || !mounted) {
        return;
      }
      setState(() {
        _pickupPlace = silentPlace;
        _pickupController.text = silentPlace.label;
      });
      await AppPreferencesService.saveLastPickupPlace(silentPlace);
      await _loadNearbyDrivers(userPlace: silentPlace);
    } catch (_) {
      // Non-blocking fallback. User can still choose location manually.
    }
  }

  String _vehicleLabel(AppStrings strings, TowVehicleKind kind) {
    switch (kind) {
      case TowVehicleKind.sedan:
        return strings.text('estimateSedan');
      case TowVehicleKind.suv:
        return strings.text('estimateSuv');
      case TowVehicleKind.motorcycle:
        return strings.text('estimateMotorcycle');
      case TowVehicleKind.flatbed:
        return strings.text('estimateFlatbed');
    }
  }

  double get _baseFare {
    switch (_vehicleKind) {
      case TowVehicleKind.sedan:
        return 8.0;
      case TowVehicleKind.suv:
        return 10.5;
      case TowVehicleKind.motorcycle:
        return 6.5;
      case TowVehicleKind.flatbed:
        return 13.5;
    }
  }

  double get _perKmRate {
    switch (_vehicleKind) {
      case TowVehicleKind.sedan:
        return 0.85;
      case TowVehicleKind.suv:
        return 1.0;
      case TowVehicleKind.motorcycle:
        return 0.70;
      case TowVehicleKind.flatbed:
        return 1.35;
    }
  }

  double get _distanceKm => _routeInfo?.distanceKm ?? 0;
  int get _etaMinutes =>
      _routeInfo?.durationMinutes ?? (_serviceTiming == 0 ? 15 : 30);
  double get _distanceFare => _distanceKm * _perKmRate;
  double get _totalFare => _baseFare + _distanceFare;

  Future<void> _pickLocation(
      {required bool isPickup, required AppStrings strings}) async {
    final selected = await BahrainPlaceSearchSheet.show(
      context,
      language: widget.language,
      title: isPickup
          ? strings.text('pickupLocation')
          : strings.text('destination'),
      initialQuery:
          isPickup ? _pickupController.text : _destinationController.text,
    );

    if (selected == null) {
      return;
    }

    setState(() {
      if (isPickup) {
        _pickupPlace = selected;
        _pickupController.text = selected.label;
      } else {
        _destinationPlace = selected;
        _destinationController.text = selected.label;
      }
    });

    if (isPickup) {
      await AppPreferencesService.saveLastPickupPlace(selected);
      await _loadNearbyDrivers(userPlace: selected);
    }

    await _refreshRoute();
  }

  Future<void> _refreshRoute() async {
    if (_pickupPlace == null || _destinationPlace == null) {
      setState(() {
        _routeInfo = null;
        _routeError = null;
      });
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    try {
      final route = await BahrainMapService.buildRoute(
        start: _pickupPlace!.latLng,
        end: _destinationPlace!.latLng,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _routeInfo = route;
        _isLoadingRoute = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routeInfo = null;
        _isLoadingRoute = false;
        _routeError = _isArabic
            ? 'تعذر حساب المسار الآن.'
            : 'Could not calculate the route right now.';
      });
    }
  }

  Future<void> _useCurrentLocation({
    required bool isPickup,
    required AppStrings strings,
  }) async {
    if (!_shareLocationEnabled) {
      final message = _isArabic
          ? 'قم بتفعيل مشاركة الموقع من الإعدادات أولاً.'
          : 'Enable "Share location" from Settings first.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    setState(() {
      _isFetchingCurrentLocation = true;
    });

    try {
      final place = await LocationService.getCurrentPlace();
      if (!mounted) {
        return;
      }

      setState(() {
        if (isPickup) {
          _pickupPlace = place;
          _pickupController.text = place.label;
        } else {
          _destinationPlace = place;
          _destinationController.text = place.label;
        }
      });

      if (isPickup) {
        await AppPreferencesService.saveLastPickupPlace(place);
        await _loadNearbyDrivers(userPlace: place);
      }

      await _refreshRoute();
    } on LocationServiceDisabledException {
      if (!mounted) {
        return;
      }
      final message = _isArabic
          ? 'فعّل خدمة الموقع في الهاتف أولاً.'
          : 'Please enable device location services first.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on LocationPermissionDeniedForeverException {
      if (!mounted) {
        return;
      }
      final message = _isArabic
          ? 'صلاحية الموقع مرفوضة نهائياً. افتح إعدادات التطبيق.'
          : 'Location permission is permanently denied. Open app settings.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on LocationPermissionDeniedException {
      if (!mounted) {
        return;
      }
      final message = _isArabic
          ? 'تم رفض صلاحية الموقع.'
          : 'Location permission was denied.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      final message = _isArabic
          ? 'تعذر الحصول على موقعك الحالي الآن.'
          : 'Could not fetch your current location right now.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingCurrentLocation = false;
        });
      }
    }
  }

  Future<void> _loadNearbyDrivers({required PlaceResult userPlace}) async {
    setState(() {
      _isLoadingNearbyDrivers = true;
    });

    try {
      final profiles = await _pocketBaseService.getDriverProfiles(limit: 200);
      var candidates =
          _buildNearbyDriversFromProfiles(profiles, userPlace: userPlace);
      candidates = candidates
          .where((driver) => driver.distanceKm <= 12.0)
          .toList(growable: false);

      if (candidates.isEmpty) {
        candidates = _buildFallbackNearbyDrivers(userPlace: userPlace);
      }

      candidates.sort((a, b) => _aiScore(b).compareTo(_aiScore(a)));
      final topFive = candidates.take(5).toList(growable: false);

      if (!mounted) {
        return;
      }
      setState(() {
        _nearbyDrivers = topFive;
        _isLoadingNearbyDrivers = false;
      });
    } catch (_) {
      final fallback = _buildFallbackNearbyDrivers(userPlace: userPlace)
          .take(5)
          .toList(growable: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _nearbyDrivers = fallback;
        _isLoadingNearbyDrivers = false;
      });
    }
  }

  List<NearbyDriver> _buildNearbyDriversFromProfiles(
    List<RecordModel> profiles, {
    required PlaceResult userPlace,
  }) {
    final drivers = <NearbyDriver>[];
    for (final record in profiles) {
      final lat = _extractCoordinate(record, const <String>[
        'driver_lat',
        'current_lat',
        'lat',
        'latitude',
      ]);
      final lng = _extractCoordinate(record, const <String>[
        'driver_lng',
        'current_lng',
        'lng',
        'longitude',
      ]);
      if (lat == null || lng == null) {
        continue;
      }

      final location = LatLng(lat, lng);
      final distanceKm = _distanceCalculator.as(
        LengthUnit.Kilometer,
        userPlace.latLng,
        location,
      );
      final name = _firstNonEmpty(<String>[
        record.getStringValue('driver_name'),
        record.getStringValue('name'),
      ]);
      final resolvedName =
          name.isEmpty ? 'Driver ${drivers.length + 1}' : name.trim();
      final rating = _extractDouble(record, const <String>[
        'driver_rating',
        'rating',
      ]);
      final rides = _extractInt(record, const <String>[
        'driver_total_rides',
        'total_rides',
        'rides',
      ]);
      final plate = _firstNonEmpty(<String>[
        record.getStringValue('license_plate'),
        record.getStringValue('plate'),
      ]);

      drivers.add(
        NearbyDriver(
          id: record.id,
          name: resolvedName,
          place: PlaceResult(
            title: resolvedName,
            subtitle: _isArabic
                ? 'يبعد ${distanceKm.toStringAsFixed(1)} كم'
                : '${distanceKm.toStringAsFixed(1)} km away',
            latitude: lat,
            longitude: lng,
          ),
          distanceKm: distanceKm,
          rating: rating,
          totalRides: rides,
          licensePlate: plate.isEmpty ? null : plate,
        ),
      );
    }
    return drivers;
  }

  List<NearbyDriver> _buildFallbackNearbyDrivers({
    required PlaceResult userPlace,
  }) {
    const offsets = <(double lat, double lng)>[
      (-0.0045, 0.0032),
      (0.0038, -0.0040),
      (0.0060, 0.0012),
      (-0.0028, -0.0064),
      (0.0055, 0.0048),
      (-0.0065, 0.0025),
      (0.0020, -0.0070),
    ];

    final drivers = <NearbyDriver>[];
    for (var index = 0; index < offsets.length; index++) {
      final offset = offsets[index];
      final lat = userPlace.latitude + offset.$1;
      final lng = userPlace.longitude + offset.$2;
      final location = LatLng(lat, lng);
      final distanceKm = _distanceCalculator.as(
        LengthUnit.Kilometer,
        userPlace.latLng,
        location,
      );
      final rating = 4.2 + ((index % 4) * 0.2);
      final rides = 80 + (index * 35);
      final name = _isArabic ? 'سائق ${index + 1}' : 'Driver ${index + 1}';
      drivers.add(
        NearbyDriver(
          id: 'sim_$index',
          name: name,
          place: PlaceResult(
            title: name,
            subtitle: _isArabic
                ? 'يبعد ${distanceKm.toStringAsFixed(1)} كم'
                : '${distanceKm.toStringAsFixed(1)} km away',
            latitude: lat,
            longitude: lng,
          ),
          distanceKm: distanceKm,
          rating: rating,
          totalRides: rides,
          licensePlate: 'TOW-${2400 + index}',
        ),
      );
    }
    return drivers;
  }

  double _aiScore(NearbyDriver driver) {
    final distanceScore = 1 / (0.15 + driver.distanceKm);
    final ratingScore = (driver.rating.clamp(0, 5) / 5.0);
    final experienceScore = (math.min(driver.totalRides, 1500) / 1500);
    return (distanceScore * 0.75) +
        (ratingScore * 0.2) +
        (experienceScore * 0.05);
  }

  double? _extractCoordinate(RecordModel record, List<String> keys) {
    for (final key in keys) {
      final numeric = record.getDoubleValue(key);
      if (numeric != 0) {
        return numeric;
      }
      final textValue = record.getStringValue(key).trim();
      if (textValue.isEmpty) {
        continue;
      }
      final parsed = double.tryParse(textValue);
      if (parsed != null && parsed != 0) {
        return parsed;
      }
    }
    return null;
  }

  double _extractDouble(RecordModel record, List<String> keys) {
    for (final key in keys) {
      final numeric = record.getDoubleValue(key);
      if (numeric != 0) {
        return numeric;
      }
      final textValue = record.getStringValue(key).trim();
      if (textValue.isEmpty) {
        continue;
      }
      final parsed = double.tryParse(textValue);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  int _extractInt(RecordModel record, List<String> keys) {
    for (final key in keys) {
      final numeric = record.getIntValue(key);
      if (numeric != 0) {
        return numeric;
      }
      final textValue = record.getStringValue(key).trim();
      if (textValue.isEmpty) {
        continue;
      }
      final parsed = int.tryParse(textValue);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  Future<void> _submitRequest(
    AppStrings strings, {
    NearbyDriver? preferredDriver,
  }) async {
    if (_pickupPlace == null || _destinationPlace == null) {
      final message = _isArabic
          ? 'يرجى اختيار موقع الالتقاط والوجهة.'
          : 'Please select both pickup and destination locations.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final towRequest = await _pocketBaseService.createTowRequest(
        pickupLocation: _pickupController.text.trim(),
        destination: _destinationController.text.trim(),
        vehicleType: _vehicleLabel(strings, _vehicleKind),
        details: _detailsController.text.trim(),
        serviceTiming: _serviceTiming == 0 ? 'immediate' : 'scheduled',
        status: preferredDriver == null ? 'pending' : 'assigned',
        pickupLat: _pickupPlace?.latitude,
        pickupLng: _pickupPlace?.longitude,
        destinationLat: _destinationPlace?.latitude,
        destinationLng: _destinationPlace?.longitude,
        driverLat: preferredDriver?.place.latitude,
        driverLng: preferredDriver?.place.longitude,
        driverName: preferredDriver?.name,
        driverRating: preferredDriver?.rating,
        driverTotalRides: preferredDriver?.totalRides,
        licensePlate: preferredDriver?.licensePlate,
        distanceKm: _distanceKm == 0 ? null : _distanceKm,
        etaMinutes: _etaMinutes,
        baseFare: _baseFare,
        distanceFare: _distanceFare,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrackServicePage(
            requestId: towRequest.id,
            pickupLocation: towRequest.pickupLocation,
            destinationLocation: towRequest.destination,
            vehicleDescription: towRequest.vehicleType,
            licensePlate: towRequest.licensePlate ?? 'Pending',
            driverName: towRequest.driverName ?? 'Assigning...',
            driverRating: towRequest.driverRating ?? 0,
            driverTotalRides: towRequest.driverTotalRides ?? 0,
            distanceKm: towRequest.distanceKm ?? _distanceKm,
            remainingDistanceKm: towRequest.distanceKm ?? _distanceKm,
            etaMinutes: towRequest.etaMinutes ?? _etaMinutes,
            baseFare: towRequest.baseFare ?? _baseFare,
            distanceFare: towRequest.distanceFare ?? _distanceFare,
            pickupLat: _pickupPlace?.latitude,
            pickupLng: _pickupPlace?.longitude,
            destinationLat: _destinationPlace?.latitude,
            destinationLng: _destinationPlace?.longitude,
            language: widget.language,
          ),
        ),
      );
    } on ClientException catch (e) {
      if (!mounted) {
        return;
      }
      final message =
          e.response['message'] as String? ?? strings.text('signInFailed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('signInFailed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String get _mapHeadline =>
      _isArabic ? 'خريطة البحرين المباشرة' : 'Live Bahrain map';
  String get _mapSubline {
    final nearest = _nearestDriver;
    final nearestText = nearest == null
        ? (_isArabic
            ? 'لا يوجد سائقون قريبون الآن.'
            : 'No nearby drivers found yet.')
        : (_isArabic
            ? 'أقرب سائق: ${nearest.name} (${nearest.distanceKm.toStringAsFixed(1)} كم)'
            : 'Closest driver: ${nearest.name} (${nearest.distanceKm.toStringAsFixed(1)} km)');

    if (_pickupPlace != null &&
        _destinationPlace != null &&
        _routeInfo != null) {
      return _isArabic
          ? '${_routeInfo!.distanceKm.toStringAsFixed(1)} كم • وصول تقريبي ${_routeInfo!.durationMinutes} دقيقة • $nearestText'
          : '${_routeInfo!.distanceKm.toStringAsFixed(1)} km • approx. ${_routeInfo!.durationMinutes} min • $nearestText';
    }
    final routeHint = _isArabic
        ? 'اختر موقع الالتقاط والوجهة لإظهار المسار.'
        : 'Pick pickup and destination to display the route.';
    return '$nearestText • $routeHint';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('requestTowService')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarqLiveMap(
              height: 280,
              pickup: _pickupPlace,
              destination: _destinationPlace,
              driver: _nearestDriver?.place,
              nearbyDrivers:
                  _nearbyDrivers.map((driver) => driver.place).toList(),
              routePoints: _routeInfo?.points ?? const <LatLng>[],
              headline: _mapHeadline,
              subline: _isLoadingRoute
                  ? (_isArabic ? 'جاري تحميل المسار...' : 'Loading route...')
                  : _mapSubline,
            ),
            const SizedBox(height: 8),
            if (_isLoadingNearbyDrivers)
              const LinearProgressIndicator(minHeight: 3),
            if (_nearestDriver != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isArabic
                            ? 'أقرب سائق: ${_nearestDriver!.name} • ${_nearestDriver!.distanceKm.toStringAsFixed(1)} كم'
                            : 'Closest driver: ${_nearestDriver!.name} • ${_nearestDriver!.distanceKm.toStringAsFixed(1)} km',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => _submitRequest(
                            strings,
                            preferredDriver: _nearestDriver,
                          ),
                  icon: const Icon(Icons.local_shipping),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(strings.text('requestThisTruckNow')),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_routeError != null) ...[
              Text(
                _routeError!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: 12),
            ],
            _sectionCard(
              context,
              title: strings.text('serviceDetails'),
              subtitle: strings.text('serviceDetailsSub'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _locationField(
                    context,
                    label: strings.text('pickupLocation'),
                    controller: _pickupController,
                    onTap: () =>
                        _pickLocation(isPickup: true, strings: strings),
                    onUseCurrentLocation: () =>
                        _useCurrentLocation(isPickup: true, strings: strings),
                  ),
                  const SizedBox(height: 12),
                  _locationField(
                    context,
                    label: strings.text('destination'),
                    controller: _destinationController,
                    onTap: () =>
                        _pickLocation(isPickup: false, strings: strings),
                    onUseCurrentLocation: () => _useCurrentLocation(
                      isPickup: false,
                      strings: strings,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TowVehicleKind>(
                    initialValue: _vehicleKind,
                    decoration: InputDecoration(
                      labelText: strings.text('vehicleType'),
                      border: const OutlineInputBorder(),
                    ),
                    items: TowVehicleKind.values
                        .map(
                          (kind) => DropdownMenuItem<TowVehicleKind>(
                            value: kind,
                            child: Text(_vehicleLabel(strings, kind)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _vehicleKind = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.text('whenNeedService'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment<int>(
                        value: 0,
                        label: Text(strings.text('immediate')),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text(strings.text('scheduleLater')),
                      ),
                    ],
                    selected: <int>{_serviceTiming},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      setState(() {
                        _serviceTiming = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: strings.text('additionalDetails'),
                      hintText: strings.text('additionalDetailsHint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: strings.text('estimateResultTitle'),
              subtitle: _isArabic
                  ? 'يتم تحديث التكلفة حسب المسار المحدد.'
                  : 'Pricing updates from the selected route.',
              child: Column(
                children: [
                  _priceRow(
                    context,
                    label: strings.text('estimateBaseFare'),
                    value: _baseFare,
                  ),
                  const SizedBox(height: 10),
                  _priceRow(
                    context,
                    label:
                        '${strings.text('estimateDistanceFare')} (${_distanceKm.toStringAsFixed(1)} km)',
                    value: _distanceFare,
                  ),
                  const SizedBox(height: 10),
                  _priceRow(
                    context,
                    label: strings.text('eta'),
                    valueText: '$_etaMinutes min',
                  ),
                  const Divider(height: 24),
                  _priceRow(
                    context,
                    label: strings.text('estimateTotal'),
                    value: _totalFare,
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : () => _submitRequest(strings),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.text('confirmRequest')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    VoidCallback? onUseCurrentLocation,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: SizedBox(
          width: 96,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onUseCurrentLocation != null)
                IconButton(
                  onPressed:
                      _isFetchingCurrentLocation ? null : onUseCurrentLocation,
                  icon: _isFetchingCurrentLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_outlined),
                ),
              IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.map_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _priceRow(
    BuildContext context, {
    required String label,
    double? value,
    String? valueText,
    bool emphasize = false,
  }) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(
          valueText ?? '${(value ?? 0).toStringAsFixed(3)} BHD',
          style: style?.copyWith(
            color: emphasize
                ? (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFF4C21E)
                    : const Color(0xFF0B1220))
                : null,
          ),
        ),
      ],
    );
  }
}
