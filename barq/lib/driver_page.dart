import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import 'models/place_result.dart';
import 'models/tow_request_model.dart';
import 'services/bahrain_map_service.dart';
import 'services/location_service.dart';
import 'services/pocketbase_service.dart';
import 'settings.dart';
import 'track_service_page.dart';
import 'widgets/barq_live_map.dart';

const Color _kDriverYellow = Color(0xFFF4C21E);
const Color _kDriverNavy = Color(0xFF0B1220);
const Color _kDriverCardDark = Color(0xFF141B2D);
const Color _kDriverBorderDark = Color(0xFF27314A);
const Color _kDriverMutedDark = Color(0xFF9AA3B2);
const Color _kDriverBorderLight = Color(0xFFE5E7EB);
const Color _kDriverMutedLight = Color(0xFF6B7280);

class DriverPage extends StatefulWidget {
  const DriverPage({
    super.key,
    required this.language,
    this.onSwitchToCustomerView,
  });

  final AppLanguage language;
  final VoidCallback? onSwitchToCustomerView;

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  final PocketBaseService _pocketBaseService = PocketBaseService.instance;

  late final TextEditingController _driverNameController;
  final TextEditingController _licensePlateController = TextEditingController();
  final TextEditingController _driverRatingController = TextEditingController(
    text: '4.8',
  );
  final TextEditingController _driverTotalRidesController =
      TextEditingController(text: '0');
  final TextEditingController _etaMinutesController = TextEditingController();
  final TextEditingController _distanceKmController = TextEditingController();

  List<TowRequest> _pendingRequests = const <TowRequest>[];
  List<TowRequest> _myActiveRequests = const <TowRequest>[];
  TowRequest? _focusedRequest;
  PlaceResult? _focusedPickupPlace;
  PlaceResult? _focusedDestinationPlace;
  RouteInfo? _focusedRouteInfo;
  String? _mapNotice;
  String _lastMapSignature = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingMap = false;
  late final bool _hasDriverAccess;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _hasDriverAccess = _pocketBaseService.isCurrentUserDriver;
    _driverNameController = TextEditingController(
      text: _pocketBaseService.currentUserName,
    );
    if (!_hasDriverAccess) {
      _isLoading = false;
      return;
    }

    _bootstrapDriverData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _loadRequests(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _driverNameController.dispose();
    _licensePlateController.dispose();
    _driverRatingController.dispose();
    _driverTotalRidesController.dispose();
    _etaMinutesController.dispose();
    _distanceKmController.dispose();
    super.dispose();
  }

  bool _isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color _cardColor(BuildContext context) {
    return _isDark(context) ? _kDriverCardDark : Colors.white;
  }

  Color _borderColor(BuildContext context) {
    return _isDark(context) ? _kDriverBorderDark : _kDriverBorderLight;
  }

  Color _mutedColor(BuildContext context) {
    return _isDark(context) ? _kDriverMutedDark : _kDriverMutedLight;
  }

  Future<void> _bootstrapDriverData() async {
    await _loadDriverProfileDefaults();
    await _loadRequests();
  }

  Future<void> _loadDriverProfileDefaults() async {
    try {
      final profile = await _pocketBaseService.getCurrentDriverProfile();
      if (profile == null || !mounted) {
        return;
      }

      final driverName = profile.getStringValue('driver_name').trim();
      final licensePlate = profile.getStringValue('license_plate').trim();
      final driverRating = profile.getDoubleValue('driver_rating');
      final totalRides = profile.getIntValue('driver_total_rides');
      final defaultEta = profile.getIntValue('default_eta_minutes');
      final defaultDistance = profile.getDoubleValue('default_distance_km');

      if (driverName.isNotEmpty) {
        _driverNameController.text = driverName;
      }
      if (licensePlate.isNotEmpty) {
        _licensePlateController.text = licensePlate;
      }
      if (driverRating > 0) {
        _driverRatingController.text = driverRating.toStringAsFixed(1);
      }
      _driverTotalRidesController.text = '$totalRides';
      if (defaultEta > 0) {
        _etaMinutesController.text = '$defaultEta';
      }
      if (defaultDistance > 0) {
        _distanceKmController.text = defaultDistance.toStringAsFixed(1);
      }
    } catch (_) {
      // Missing profile is non-blocking. Driver can still operate.
    }
  }

  Future<void> _saveDriverProfile() async {
    final driverName = _driverNameController.text.trim();
    if (driverName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver name is required.')),
      );
      return;
    }

    try {
      final currentPlace = await LocationService.tryGetCurrentPlaceSilently();
      await _pocketBaseService.upsertCurrentDriverProfile(
        driverName: driverName,
        licensePlate: _licensePlateController.text.trim(),
        driverRating: _tryParseDouble(_driverRatingController.text),
        driverTotalRides: _tryParseInt(_driverTotalRidesController.text),
        defaultEtaMinutes: _tryParseInt(_etaMinutesController.text),
        defaultDistanceKm: _tryParseDouble(_distanceKmController.text),
        driverLat: currentPlace?.latitude,
        driverLng: currentPlace?.longitude,
        isAvailable: true,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver profile saved.')),
      );
    } on ClientException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.response['message'] as String? ??
          'Could not save driver profile. Check collection rules.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save driver profile.')),
      );
    }
  }

  Future<void> _loadRequests({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final driverName = _driverNameController.text.trim();
      final results = await Future.wait<List<TowRequest>>([
        _pocketBaseService.getPendingTowRequests(),
        _pocketBaseService.getDriverActiveRequests(driverName),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingRequests = results[0];
        _myActiveRequests = results[1];
        _isLoading = false;
      });
      _syncFocusedRequestMap();
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load tow requests from PocketBase.'),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  TowRequest? _preferredMapRequest() {
    if (_myActiveRequests.isNotEmpty) {
      return _myActiveRequests.first;
    }
    if (_pendingRequests.isNotEmpty) {
      return _pendingRequests.first;
    }
    return null;
  }

  String _requestMapSignature(TowRequest request) {
    return [
      request.id,
      request.pickupLocation,
      request.destination,
      request.pickupLat?.toStringAsFixed(6) ?? '',
      request.pickupLng?.toStringAsFixed(6) ?? '',
      request.destinationLat?.toStringAsFixed(6) ?? '',
      request.destinationLng?.toStringAsFixed(6) ?? '',
      request.status,
    ].join('|');
  }

  Future<void> _syncFocusedRequestMap({TowRequest? forcedRequest}) async {
    TowRequest? currentVisibleFocus;
    if (_focusedRequest != null) {
      for (final item in [..._myActiveRequests, ..._pendingRequests]) {
        if (item.id == _focusedRequest!.id) {
          currentVisibleFocus = item;
          break;
        }
      }
    }

    final nextRequest =
        forcedRequest ?? currentVisibleFocus ?? _preferredMapRequest();
    if (nextRequest == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _focusedRequest = null;
        _focusedPickupPlace = null;
        _focusedDestinationPlace = null;
        _focusedRouteInfo = null;
        _mapNotice = null;
        _lastMapSignature = '';
        _isLoadingMap = false;
      });
      return;
    }

    final nextSignature = _requestMapSignature(nextRequest);
    if (forcedRequest == null &&
        nextSignature == _lastMapSignature &&
        _focusedPickupPlace != null) {
      if (mounted && _focusedRequest?.id != nextRequest.id) {
        setState(() {
          _focusedRequest = nextRequest;
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _focusedRequest = nextRequest;
      _lastMapSignature = nextSignature;
      _isLoadingMap = true;
      _mapNotice = null;
    });

    final pickup = await _resolvePlaceForMap(
      label: nextRequest.pickupLocation,
      latitude: nextRequest.pickupLat,
      longitude: nextRequest.pickupLng,
    );
    final destination = await _resolvePlaceForMap(
      label: nextRequest.destination,
      latitude: nextRequest.destinationLat,
      longitude: nextRequest.destinationLng,
    );

    RouteInfo? routeInfo;
    if (pickup != null && destination != null) {
      try {
        routeInfo = await BahrainMapService.buildRoute(
          start: pickup.latLng,
          end: destination.latLng,
        );
      } catch (_) {
        routeInfo = null;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _focusedPickupPlace = pickup;
      _focusedDestinationPlace = destination;
      _focusedRouteInfo = routeInfo;
      _isLoadingMap = false;
      _mapNotice = _buildMapNotice(
        pickup: pickup,
        destination: destination,
        routeInfo: routeInfo,
      );
    });
  }

  Future<PlaceResult?> _resolvePlaceForMap({
    required String label,
    required double? latitude,
    required double? longitude,
  }) async {
    final cleanLabel = label.trim();
    if (latitude != null && longitude != null) {
      return PlaceResult(
        title: _titleFromLabel(cleanLabel),
        subtitle: _subtitleFromLabel(cleanLabel),
        latitude: latitude,
        longitude: longitude,
      );
    }

    if (cleanLabel.isEmpty) {
      return null;
    }

    final geocoded = await BahrainMapService.geocode(cleanLabel);
    if (geocoded == null) {
      return null;
    }

    return geocoded.copyWith(
      title: _titleFromLabel(cleanLabel),
      subtitle: cleanLabel,
    );
  }

  String _titleFromLabel(String label) {
    final clean = label.trim();
    if (clean.isEmpty) {
      return 'Location';
    }
    return clean.split(',').first.trim();
  }

  String _subtitleFromLabel(String label) {
    final clean = label.trim();
    if (clean.isEmpty || !clean.contains(',')) {
      return '';
    }
    final parts = clean.split(',').map((part) => part.trim()).toList();
    if (parts.length < 2) {
      return '';
    }
    return parts.sublist(1).join(' - ');
  }

  String? _buildMapNotice({
    required PlaceResult? pickup,
    required PlaceResult? destination,
    required RouteInfo? routeInfo,
  }) {
    if (pickup == null) {
      return 'Customer pickup location could not be resolved on the map.';
    }
    if (destination == null) {
      return 'Destination marker is unavailable for this request.';
    }
    if (routeInfo == null) {
      return 'Markers are visible, but route calculation is unavailable right now.';
    }
    return null;
  }

  double? _tryParseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  int? _tryParseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  Future<void> _acceptRequest(TowRequest request) async {
    final driverName = _driverNameController.text.trim();
    if (driverName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter driver name first.')),
      );
      return;
    }

    final driverRating = _tryParseDouble(_driverRatingController.text);
    final driverTotalRides = _tryParseInt(_driverTotalRidesController.text);
    final etaMinutes =
        _tryParseInt(_etaMinutesController.text) ?? request.etaMinutes;
    final distanceKm =
        _tryParseDouble(_distanceKmController.text) ?? request.distanceKm;

    await _updateRequest(
      request: request,
      status: 'assigned',
      driverName: driverName,
      driverRating: driverRating,
      driverTotalRides: driverTotalRides,
      etaMinutes: etaMinutes,
      distanceKm: distanceKm,
    );
  }

  Future<void> _startTrip(TowRequest request) async {
    await _updateRequest(
      request: request,
      status: 'en_route',
      driverName: _driverNameController.text.trim(),
      driverRating:
          request.driverRating ?? _tryParseDouble(_driverRatingController.text),
      driverTotalRides: request.driverTotalRides ??
          _tryParseInt(_driverTotalRidesController.text),
      etaMinutes:
          _tryParseInt(_etaMinutesController.text) ?? request.etaMinutes,
      distanceKm:
          _tryParseDouble(_distanceKmController.text) ?? request.distanceKm,
    );
  }

  Future<void> _completeTrip(TowRequest request) async {
    await _updateRequest(
      request: request,
      status: 'completed',
      driverName: _driverNameController.text.trim(),
      driverRating:
          request.driverRating ?? _tryParseDouble(_driverRatingController.text),
      driverTotalRides: request.driverTotalRides ??
          _tryParseInt(_driverTotalRidesController.text),
      etaMinutes: 0,
      distanceKm: request.distanceKm,
    );
  }

  Future<void> _updateRequest({
    required TowRequest request,
    required String status,
    String? driverName,
    double? driverRating,
    int? driverTotalRides,
    int? etaMinutes,
    double? distanceKm,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _pocketBaseService.updateTowRequestAsDriver(
        requestId: request.id,
        status: status,
        driverName: driverName,
        licensePlate: request.licensePlate?.trim().isNotEmpty == true
            ? request.licensePlate
            : _licensePlateController.text.trim(),
        driverRating: driverRating,
        driverTotalRides: driverTotalRides,
        etaMinutes: etaMinutes,
        distanceKm: distanceKm,
        baseFare: request.baseFare,
        distanceFare: request.distanceFare,
      );

      if (!mounted) {
        return;
      }

      await _loadRequests(silent: true);
    } on ClientException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.response['message'] as String? ??
          'Could not update request. Please check your collection rules.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update request.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _statusLabel(String status, AppStrings strings) {
    switch (status) {
      case 'pending':
        return strings.text('pending');
      case 'assigned':
        return strings.text('assigned');
      case 'en_route':
        return strings.text('enRoute');
      case 'completed':
        return strings.text('completed');
      case 'cancelled':
        return strings.text('cancelled');
      default:
        return status;
    }
  }

  void _openTracking(TowRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackServicePage(
          requestId: request.id,
          pickupLocation: request.pickupLocation,
          destinationLocation: request.destination,
          vehicleDescription: request.vehicleType,
          licensePlate:
              request.licensePlate ?? _licensePlateController.text.trim(),
          driverName: request.driverName ?? _driverNameController.text.trim(),
          driverRating: request.driverRating ??
              _tryParseDouble(_driverRatingController.text) ??
              0,
          driverTotalRides: request.driverTotalRides ??
              _tryParseInt(_driverTotalRidesController.text) ??
              0,
          distanceKm: request.distanceKm ?? 0,
          remainingDistanceKm: request.distanceKm ?? 0,
          etaMinutes: request.etaMinutes ?? 0,
          baseFare: request.baseFare ?? 0,
          distanceFare: request.distanceFare ?? 0,
          pickupLat: request.pickupLat,
          pickupLng: request.pickupLng,
          destinationLat: request.destinationLat,
          destinationLng: request.destinationLng,
          driverLat: request.driverLat,
          driverLng: request.driverLng,
          language: widget.language,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);
    if (!_hasDriverAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Driver Panel')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildEmptyCard(
              context,
              message:
                  'Access denied. This screen is available only for users with driver role.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Panel'),
        actions: [
          if (widget.onSwitchToCustomerView != null)
            IconButton(
              tooltip: 'Customer Dashboard',
              onPressed: widget.onSwitchToCustomerView,
              icon: const Icon(Icons.person_outline),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isSaving ? null : _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildDriverProfileCard(context),
            const SizedBox(height: 14),
            _buildLiveMapCard(context, strings),
            const SizedBox(height: 14),
            _buildSectionHeader(
              context,
              title: 'Pending Requests',
              count: _pendingRequests.length,
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_pendingRequests.isEmpty)
              _buildEmptyCard(
                context,
                message: 'No pending requests right now.',
              )
            else
              ..._pendingRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildRequestCard(
                    context,
                    request: request,
                    strings: strings,
                    isPending: true,
                    isFocused: _focusedRequest?.id == request.id,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildSectionHeader(
              context,
              title: 'My Active Jobs',
              count: _myActiveRequests.length,
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              const SizedBox.shrink()
            else if (_myActiveRequests.isEmpty)
              _buildEmptyCard(
                context,
                message: 'No assigned jobs for this driver name.',
              )
            else
              ..._myActiveRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildRequestCard(
                    context,
                    request: request,
                    strings: strings,
                    isPending: false,
                    isFocused: _focusedRequest?.id == request.id,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverProfileCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Driver Defaults',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'These values are written to tow_requests when you accept or update a job.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _driverNameController,
            decoration: const InputDecoration(
              labelText: 'driver_name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _loadRequests(silent: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _licensePlateController,
                  decoration: const InputDecoration(
                    labelText: 'license_plate',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _driverRatingController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'driver_rating',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _driverTotalRidesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'driver_total_rides',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _etaMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'eta_minutes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _distanceKmController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'distance_km',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () async {
                      await _saveDriverProfile();
                      await _loadRequests(silent: true);
                    },
              icon: const Icon(Icons.sync),
              label: const Text('Save Driver Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMapCard(BuildContext context, AppStrings strings) {
    final focused = _focusedRequest;
    final mapSubline = _isLoadingMap
        ? 'Loading customer location...'
        : (focused == null
            ? 'No pending or active request to display.'
            : '${_statusLabel(focused.status, strings)} | ${focused.pickupLocation}');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Customer Location Map',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (focused != null)
                Text(
                  '#${focused.id.substring(0, focused.id.length > 8 ? 8 : focused.id.length)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _mutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap any request card below to focus this map on that customer.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
          const SizedBox(height: 12),
          BarqLiveMap(
            height: 240,
            pickup: _focusedPickupPlace,
            destination: _focusedDestinationPlace,
            routePoints: _focusedRouteInfo?.points ?? const [],
            headline: 'Customer pickup location',
            subline: mapSubline,
          ),
          if (_isLoadingMap)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_mapNotice != null) ...[
            const SizedBox(height: 10),
            Text(
              _mapNotice!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedColor(context),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kDriverYellow.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _kDriverNavy,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: _mutedColor(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedColor(context),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context, {
    required TowRequest request,
    required AppStrings strings,
    required bool isPending,
    required bool isFocused,
  }) {
    final statusLabel = _statusLabel(request.status, strings);
    final fareText = request.totalFare > 0
        ? '${request.totalFare.toStringAsFixed(3)} BHD'
        : '--';
    final etaText =
        request.etaMinutes != null ? '${request.etaMinutes} min' : '--';
    final distanceText = request.distanceKm != null
        ? '${request.distanceKm!.toStringAsFixed(1)} km'
        : '--';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isSaving
            ? null
            : () {
                _syncFocusedRequestMap(forcedRequest: request);
              },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? _kDriverYellow : _borderColor(context),
              width: isFocused ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.pickupLocation,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.destination,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _mutedColor(context),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kDriverYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _kDriverNavy,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'vehicle_type: ${request.vehicleType}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'service_timing: ${request.serviceTiming}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'driver_name: ${request.driverName ?? '--'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'license_plate: ${request.licensePlate ?? '--'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'driver_rating: ${request.driverRating?.toStringAsFixed(1) ?? '--'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'driver_total_rides: ${request.driverTotalRides?.toString() ?? '--'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'base_fare: ${request.baseFare?.toStringAsFixed(3) ?? '--'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'distance_fare: ${request.distanceFare?.toStringAsFixed(3) ?? '--'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (request.details.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'details: ${request.details}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metricTile(
                      context,
                      title: 'eta_minutes',
                      value: etaText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile(
                      context,
                      title: 'distance_km',
                      value: distanceText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile(
                      context,
                      title: 'total_fare',
                      value: fareText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openTracking(request),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Track'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPrimaryAction(
                      request: request,
                      isPending: isPending,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryAction({
    required TowRequest request,
    required bool isPending,
  }) {
    if (isPending) {
      return FilledButton.icon(
        onPressed: _isSaving ? null : () => _acceptRequest(request),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Accept'),
      );
    }

    if (request.status == 'assigned') {
      return FilledButton.icon(
        onPressed: _isSaving ? null : () => _startTrip(request),
        icon: const Icon(Icons.directions_car_filled_outlined),
        label: const Text('Start Trip'),
      );
    }

    return FilledButton.icon(
      onPressed: _isSaving ? null : () => _completeTrip(request),
      style: FilledButton.styleFrom(
        backgroundColor: _kDriverYellow,
        foregroundColor: _kDriverNavy,
      ),
      icon: const Icon(Icons.task_alt),
      label: const Text('Complete'),
    );
  }

  Widget _metricTile(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _isDark(context) ? _kDriverNavy : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
