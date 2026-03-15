import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pocketbase/pocketbase.dart';

import 'models/place_result.dart';
import 'services/bahrain_map_service.dart';
import 'services/pocketbase_service.dart';
import 'settings.dart';
import 'track_service_page.dart';
import 'widgets/barq_live_map.dart';
import 'widgets/place_search_sheet.dart';

enum TowVehicleKind { sedan, suv, motorcycle, flatbed }

class RequestTowPage extends StatefulWidget {
  const RequestTowPage({super.key, required this.language});

  final AppLanguage language;

  @override
  State<RequestTowPage> createState() => _RequestTowPageState();
}

class _RequestTowPageState extends State<RequestTowPage> {
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
  String? _routeError;

  bool get _isArabic => widget.language == AppLanguage.ar;

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _detailsController.dispose();
    super.dispose();
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
  int get _etaMinutes => _routeInfo?.durationMinutes ?? (_serviceTiming == 0 ? 15 : 30);
  double get _distanceFare => _distanceKm * _perKmRate;
  double get _totalFare => _baseFare + _distanceFare;

  Future<void> _pickLocation({required bool isPickup, required AppStrings strings}) async {
    final selected = await BahrainPlaceSearchSheet.show(
      context,
      language: widget.language,
      title: isPickup ? strings.text('pickupLocation') : strings.text('destination'),
      initialQuery: isPickup ? _pickupController.text : _destinationController.text,
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

  Future<void> _submitRequest(AppStrings strings) async {
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
        pickupLat: _pickupPlace?.latitude,
        pickupLng: _pickupPlace?.longitude,
        destinationLat: _destinationPlace?.latitude,
        destinationLng: _destinationPlace?.longitude,
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

  String get _mapHeadline => _isArabic ? 'خريطة البحرين المباشرة' : 'Live Bahrain map';
  String get _mapSubline {
    if (_pickupPlace != null && _destinationPlace != null && _routeInfo != null) {
      return _isArabic
          ? '${_routeInfo!.distanceKm.toStringAsFixed(1)} كم • وصول تقريبي ${_routeInfo!.durationMinutes} دقيقة'
          : '${_routeInfo!.distanceKm.toStringAsFixed(1)} km • approx. ${_routeInfo!.durationMinutes} min';
    }
    return _isArabic
        ? 'اختر موقع الالتقاط والوجهة لإظهار المسار.'
        : 'Pick pickup and destination to display the route.';
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
              routePoints: _routeInfo?.points ?? const <LatLng>[],
              headline: _mapHeadline,
              subline: _isLoadingRoute ? (_isArabic ? 'جاري تحميل المسار...' : 'Loading route...') : _mapSubline,
            ),
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
                    onTap: () => _pickLocation(isPickup: true, strings: strings),
                  ),
                  const SizedBox(height: 12),
                  _locationField(
                    context,
                    label: strings.text('destination'),
                    controller: _destinationController,
                    onTap: () => _pickLocation(isPickup: false, strings: strings),
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
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.map_outlined),
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
            color: emphasize ? const Color(0xFF16A34A) : null,
          ),
        ),
      ],
    );
  }
}
