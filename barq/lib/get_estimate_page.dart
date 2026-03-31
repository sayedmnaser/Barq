import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'models/place_result.dart';
import 'services/app_preferences_service.dart';
import 'services/bahrain_map_service.dart';
import 'services/location_service.dart';
import 'settings.dart';
import 'widgets/barq_live_map.dart';
import 'widgets/place_search_sheet.dart';

enum EstimateVehicleType { sedan, suv, motorcycle, flatbed }

class GetEstimatePage extends StatefulWidget {
  const GetEstimatePage({super.key, required this.language});

  final AppLanguage language;

  @override
  State<GetEstimatePage> createState() => _GetEstimatePageState();
}

class _GetEstimatePageState extends State<GetEstimatePage> {
  static const double _minimumFareBhd = 5.0;
  static const double _maximumDayFareBhd = 20.0;
  static const double _nightSurchargeBhd = 5.0;

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  PlaceResult? _pickupPlace;
  PlaceResult? _destinationPlace;
  RouteInfo? _routeInfo;

  EstimateVehicleType _vehicleType = EstimateVehicleType.sedan;
  bool _nightService = false;
  bool _isLoadingRoute = false;
  bool _isFetchingCurrentLocation = false;
  bool _shareLocationEnabled = true;
  String? _routeError;

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
  }

  String _vehicleTypeLabel(AppStrings strings, EstimateVehicleType type) {
    switch (type) {
      case EstimateVehicleType.sedan:
        return strings.text('estimateSedan');
      case EstimateVehicleType.suv:
        return strings.text('estimateSuv');
      case EstimateVehicleType.motorcycle:
        return strings.text('estimateMotorcycle');
      case EstimateVehicleType.flatbed:
        return strings.text('estimateFlatbed');
    }
  }

  double get _baseFare => _minimumFareBhd;

  double get _perKmRate {
    switch (_vehicleType) {
      case EstimateVehicleType.sedan:
        return 0.75;
      case EstimateVehicleType.suv:
        return 0.95;
      case EstimateVehicleType.motorcycle:
        return 0.60;
      case EstimateVehicleType.flatbed:
        return 1.20;
    }
  }

  double get _distanceKm => _routeInfo?.distanceKm ?? 0;
  double get _rawDistanceFare => _distanceKm * _perKmRate;
  double get _distanceFare {
    final cappedDistanceFare =
        _rawDistanceFare.clamp(0.0, _maximumDayFareBhd - _minimumFareBhd);
    return cappedDistanceFare.toDouble();
  }

  double get _serviceFee => 0.0;
  double get _dayFare => (_baseFare + _distanceFare)
      .clamp(_minimumFareBhd, _maximumDayFareBhd)
      .toDouble();
  double get _surcharge => _nightService ? _nightSurchargeBhd : 0;
  double get _total => _dayFare + _surcharge;

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

    await _calculateRoute();
  }

  Future<void> _calculateRoute() async {
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
      await _calculateRoute();
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

  String get _mapHeadline =>
      _isArabic ? 'تقدير على خريطة البحرين' : 'Bahrain map estimate';
  String get _mapSubline {
    if (_routeInfo == null) {
      return _isArabic
          ? 'اختر نقطتين لمعرفة المسافة والتكلفة.'
          : 'Choose two Bahrain locations to estimate distance and price.';
    }
    return _isArabic
        ? '${_routeInfo!.distanceKm.toStringAsFixed(1)} كم • ${_routeInfo!.durationMinutes} دقيقة تقريبًا'
        : '${_routeInfo!.distanceKm.toStringAsFixed(1)} km • about ${_routeInfo!.durationMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('getEstimate')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarqLiveMap(
              height: 280,
              pickup: _pickupPlace,
              destination: _destinationPlace,
              routePoints: _routeInfo?.points ?? const <LatLng>[],
              headline: _mapHeadline,
              subline: _isLoadingRoute
                  ? (_isArabic ? 'جاري تحميل المسار...' : 'Loading route...')
                  : _mapSubline,
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: strings.text('estimateTitle'),
              subtitle: strings.text('estimateSubtitle'),
              child: Column(
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
                  DropdownButtonFormField<EstimateVehicleType>(
                    initialValue: _vehicleType,
                    decoration: InputDecoration(
                      labelText: strings.text('vehicleType'),
                      border: const OutlineInputBorder(),
                    ),
                    items: EstimateVehicleType.values
                        .map(
                          (type) => DropdownMenuItem<EstimateVehicleType>(
                            value: type,
                            child: Text(_vehicleTypeLabel(strings, type)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _vehicleType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _nightService,
                    title: Text(strings.text('estimateNightService')),
                    subtitle: Text(strings.text('estimateNightServiceSub')),
                    onChanged: (value) {
                      setState(() {
                        _nightService = value;
                      });
                    },
                  ),
                  if (_routeError != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _routeError!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: strings.text('estimateResultTitle'),
              child: Column(
                children: [
                  _estimateRow(
                    context,
                    label: strings.text('estimateBaseFare'),
                    value: _baseFare,
                  ),
                  const SizedBox(height: 8),
                  _estimateRow(
                    context,
                    label:
                        '${strings.text('estimateDistanceFare')} (${_distanceKm.toStringAsFixed(1)} km)',
                    value: _distanceFare,
                  ),
                  const SizedBox(height: 8),
                  if (_serviceFee > 0) ...[
                    const SizedBox(height: 8),
                    _estimateRow(
                      context,
                      label: strings.text('estimateServiceFee'),
                      value: _serviceFee,
                    ),
                  ],
                  if (_surcharge > 0) ...[
                    const SizedBox(height: 8),
                    _estimateRow(
                      context,
                      label: strings.text('estimateNightSurcharge'),
                      value: _surcharge,
                    ),
                  ],
                  const Divider(height: 24),
                  _estimateRow(
                    context,
                    label: strings.text('estimateTotal'),
                    value: _total,
                    emphasize: true,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      strings.text('estimateDisclaimer'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                    ),
                  ),
                ],
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
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Widget _estimateRow(
    BuildContext context, {
    required String label,
    required double value,
    bool emphasize = false,
  }) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            )
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(
          '${value.toStringAsFixed(3)} BHD',
          style: style?.copyWith(
            color: emphasize ? const Color(0xFF16A34A) : null,
          ),
        ),
      ],
    );
  }
}
