import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/place_result.dart';
import 'models/tow_request_model.dart';
import 'services/bahrain_map_service.dart';
import 'services/driver_location_service.dart';
import 'services/location_service.dart';
import 'services/moderation_ai_service.dart';
import 'services/pocketbase_service.dart';
import 'settings.dart';
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
  List<TowRequest> _myHistoryRequests = const <TowRequest>[];
  List<RecordModel> _myRatings = const <RecordModel>[];
  Set<String> _declinedRequestIds = <String>{};
  double _myAverageRating = 0;
  TowRequest? _focusedRequest;
  PlaceResult? _focusedPickupPlace;
  PlaceResult? _focusedDestinationPlace;
  PlaceResult? _driverLivePlace;
  RouteInfo? _focusedRouteInfo;
  String? _mapNotice;
  String _lastMapSignature = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingMap = false;
  bool _isScanningPlate = false;
  bool _isAvailable = false;
  bool _isTowRealtimeSubscribed = false;
  late final bool _hasDriverAccess;
  Timer? _refreshTimer;
  Timer? _driverLocationTimer;

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

    _loadDeclinedIds();
    _bootstrapDriverData();
    _subscribeToRealtimeRequests();

    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _loadRequests(silent: true);
    });
    _refreshDriverLocation();
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshDriverLocation();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _driverLocationTimer?.cancel();
    if (_isTowRealtimeSubscribed) {
      _pocketBaseService.unsubscribeDriverTowRequests();
    }
    DriverLocationService.instance.stop();
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

  Future<void> _subscribeToRealtimeRequests() async {
    try {
      await _pocketBaseService.subscribeDriverTowRequests(() {
        if (mounted) {
          _loadRequests(silent: true);
        }
      });
      _isTowRealtimeSubscribed = true;
    } catch (_) {
      // The periodic refresh remains as a fallback.
    }
  }

  String? _resolveOwnPhone() {
    final record = _pocketBaseService.currentUserRecord;
    if (record == null) return null;
    final phone = record.getIntValue('phoneNumber');
    if (phone <= 0) return null;
    return '+$phone';
  }

  String get _declinedKey {
    final userId = _pocketBaseService.currentUserRecord?.id ?? 'anon';
    return 'driver_declined_$userId';
  }

  Future<void> _loadDeclinedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_declinedKey) ?? const <String>[];
      if (!mounted) return;
      setState(() {
        _declinedRequestIds = list.toSet();
      });
    } catch (_) {
      // best-effort: if SharedPreferences fails the list stays empty
    }
  }

  Future<void> _persistDeclinedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_declinedKey, _declinedRequestIds.toList());
    } catch (_) {
      // non-fatal
    }
  }

  Future<void> _declineRequest(TowRequest request) async {
    setState(() {
      _declinedRequestIds = {..._declinedRequestIds, request.id};
      _pendingRequests = _pendingRequests
          .where((item) => item.id != request.id)
          .toList(growable: false);
      if (_focusedRequest?.id == request.id) {
        _focusedRequest = null;
      }
    });
    await _persistDeclinedIds();
    _syncFocusedRequestMap();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request declined.')),
    );
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
      final available = profile.getBoolValue('is_available');
      setState(() {
        _isAvailable = available;
      });
      if (!available) {
        await DriverLocationService.instance.stop();
      } else {
        await DriverLocationService.instance.start();
      }
    } catch (_) {
      // Missing profile is non-blocking. Driver can still operate.
    }
  }

  Future<void> _saveDriverProfile({bool silent = false}) async {
    final driverName = _driverNameController.text.trim();
    if (driverName.isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver name is required.')),
        );
      }
      return;
    }

    try {
      final currentPlace = _driverLivePlace ??
          await LocationService.tryGetCurrentPlaceSilently();
      await _pocketBaseService.upsertCurrentDriverProfile(
        driverName: driverName,
        licensePlate: _licensePlateController.text.trim(),
        driverPhone: _resolveOwnPhone(),
        driverRating: _tryParseDouble(_driverRatingController.text),
        driverTotalRides: _tryParseInt(_driverTotalRidesController.text),
        defaultEtaMinutes: _tryParseInt(_etaMinutesController.text),
        defaultDistanceKm: _tryParseDouble(_distanceKmController.text),
        driverLat: currentPlace?.latitude,
        driverLng: currentPlace?.longitude,
        isAvailable: _isAvailable,
      );
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver profile saved.')),
      );
    } on ClientException catch (e) {
      if (!mounted || silent) return;
      final message = e.response['message'] as String? ??
          'Could not save driver profile. Check collection rules.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on Exception catch (e) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } catch (_) {
      if (!mounted || silent) return;
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
        _pocketBaseService.getDriverServiceHistory(driverName),
      ]);

      if (!mounted) {
        return;
      }

      final completedRideCount = results[2].length;
      final profileRideCount =
          _tryParseInt(_driverTotalRidesController.text) ?? 0;
      final shouldSyncRideCount = completedRideCount > profileRideCount;
      setState(() {
        _pendingRequests = results[0]
            .where((item) => !_declinedRequestIds.contains(item.id))
            .toList(growable: false);
        _myActiveRequests = results[1];
        _myHistoryRequests = results[2];
        if (shouldSyncRideCount) {
          _driverTotalRidesController.text = '$completedRideCount';
        }
        _isLoading = false;
      });
      if (shouldSyncRideCount) {
        _saveDriverProfile(silent: true);
      }
      await _syncFocusedRequestMap();
      _loadDriverRatings();
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

    final nextRequest = forcedRequest ?? currentVisibleFocus;
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
    await _backfillResolvedCoordinates(
      request: nextRequest,
      pickup: pickup,
      destination: destination,
    );

    RouteInfo? routeInfo;
    final driverPlace = _driverLivePlace;
    LatLng? routeStart;
    LatLng? routeEnd;
    if (driverPlace != null &&
        nextRequest.status == 'en_route' &&
        destination != null) {
      routeStart = driverPlace.latLng;
      routeEnd = destination.latLng;
    } else if (driverPlace != null &&
        (nextRequest.status == 'assigned' || nextRequest.status == 'pending') &&
        pickup != null) {
      routeStart = driverPlace.latLng;
      routeEnd = pickup.latLng;
    } else if (pickup != null && destination != null) {
      routeStart = pickup.latLng;
      routeEnd = destination.latLng;
    }
    if (routeStart != null && routeEnd != null) {
      try {
        routeInfo = await BahrainMapService.buildRoute(
          start: routeStart,
          end: routeEnd,
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
      return 'Pickup coordinates are missing for this request. New requests save exact map points after the PocketBase migration is deployed.';
    }
    if (destination == null) {
      return 'Destination coordinates are missing, so this job cannot auto-complete until the destination is resolved.';
    }
    if (routeInfo == null) {
      return 'Markers are visible, but route calculation is unavailable right now.';
    }
    return null;
  }

  Future<void> _backfillResolvedCoordinates({
    required TowRequest request,
    required PlaceResult? pickup,
    required PlaceResult? destination,
  }) async {
    final pickupMissing =
        request.pickupLat == null || request.pickupLng == null;
    final destinationMissing =
        request.destinationLat == null || request.destinationLng == null;
    if ((!pickupMissing || pickup == null) &&
        (!destinationMissing || destination == null)) {
      return;
    }

    try {
      await _pocketBaseService.updateTowRequestCoordinates(
        requestId: request.id,
        pickupLat: pickupMissing ? pickup?.latitude : null,
        pickupLng: pickupMissing ? pickup?.longitude : null,
        destinationLat: destinationMissing ? destination?.latitude : null,
        destinationLng: destinationMissing ? destination?.longitude : null,
      );
    } catch (_) {
      // Best-effort only. New requests persist coordinates at creation time.
    }
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

  static const double _kArrivalRadiusMeters = 150.0;

  Future<bool> _ensureDriverNear({
    required double? targetLat,
    required double? targetLng,
    required String label,
  }) async {
    if (targetLat == null || targetLng == null) {
      return true;
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // fall back to last cached fix from the foreground stream
      final live = _driverLivePlace;
      if (live != null) {
        final meters = BahrainMapService.distanceMeters(
          live.latitude,
          live.longitude,
          targetLat,
          targetLng,
        );
        if (meters <= _kArrivalRadiusMeters) return true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                label == 'pickup'
                    ? 'Tracking is active. Start Trip unlocks within 150 m of pickup (${meters.round()} m away).'
                    : 'Too far from $label (${meters.round()} m). Move closer to continue.',
              ),
            ),
          );
        }
        return false;
      }
      // no fix at all — refuse rather than allow false completion
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No location fix. Enable GPS and try again.',
            ),
          ),
        );
      }
      return false;
    }

    final meters = BahrainMapService.distanceMeters(
      pos.latitude,
      pos.longitude,
      targetLat,
      targetLng,
    );
    if (meters > _kArrivalRadiusMeters) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              label == 'pickup'
                  ? 'Tracking is active. Start Trip unlocks within 150 m of pickup (${meters.round()} m away).'
                  : 'Too far from $label (${meters.round()} m). Move closer to continue.',
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _startTrip(TowRequest request) async {
    final ok = await _ensureDriverNear(
      targetLat: request.pickupLat,
      targetLng: request.pickupLng,
      label: 'pickup',
    );
    if (!ok) return;
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
      final updatedRequest = await _pocketBaseService.updateTowRequestAsDriver(
        requestId: request.id,
        status: status,
        driverName: driverName,
        licensePlate: _licensePlateController.text.trim(),
        driverPhone: _resolveOwnPhone(),
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

      if (status == 'assigned' || status == 'en_route') {
        await DriverLocationService.instance.start();
        await _refreshDriverLocation();
      }

      await _loadRequests(silent: true);
      if (status == 'assigned' || status == 'en_route') {
        await _syncFocusedRequestMap(forcedRequest: updatedRequest);
      }
    } on ClientException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.response['message'] as String? ??
          'Could not update request. Please check your collection rules.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFF6B7280);
      case 'assigned':
        return const Color(0xFF2563EB);
      case 'en_route':
        return const Color(0xFFF59E0B);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'cancel_pending':
        return const Color(0xFFB45309);
      default:
        return _kDriverYellow;
    }
  }

  Widget _coloredStatusPill(
    BuildContext context,
    String status,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
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

  void _openFullscreenMap(TowRequest? focused, String? subline) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenMapPage(
          pickup: _focusedPickupPlace,
          destination: _focusedDestinationPlace,
          driver: _driverLivePlace,
          routePoints: _focusedRouteInfo?.points ?? const [],
          headline: focused == null
              ? 'Your live position'
              : 'Customer pickup -> destination',
          subline: subline,
        ),
      ),
    );
  }

  Future<void> _openTracking(TowRequest request) async {
    await _syncFocusedRequestMap(forcedRequest: request);
    if (!mounted) {
      return;
    }

    final strings = AppStrings(widget.language);
    _openFullscreenMap(
      _focusedRequest ?? request,
      '${_statusLabel(request.status, strings)} | ${request.pickupLocation}',
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
            const SizedBox(height: 16),
            _buildSectionHeader(
              context,
              title: 'Service History',
              count: _myHistoryRequests.length,
            ),
            const SizedBox(height: 10),
            if (_isLoading)
              const SizedBox.shrink()
            else if (_myHistoryRequests.isEmpty)
              _buildEmptyCard(
                context,
                message: 'No completed jobs yet.',
              )
            else
              ..._myHistoryRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildHistoryCard(
                    context,
                    request: request,
                    strings: strings,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildRatingsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context, {
    required TowRequest request,
    required AppStrings strings,
  }) {
    final fareText = request.totalFare > 0
        ? '${request.totalFare.toStringAsFixed(3)} BHD'
        : '--';
    final distanceText = request.distanceKm != null
        ? '${request.distanceKm!.toStringAsFixed(1)} km'
        : '--';
    final etaText =
        request.etaMinutes != null ? '${request.etaMinutes} min' : '--';
    final completedDate =
        '${request.updated.year}-${request.updated.month.toString().padLeft(2, '0')}-${request.updated.day.toString().padLeft(2, '0')}';

    final photos = <(String label, String fileName)>[
      if (request.pickupPhoto != null) ('Pickup', request.pickupPhoto!),
      if (request.dropoffPhoto != null) ('Dropoff', request.dropoffPhoto!),
      ...request.damagePhotos
          .asMap()
          .entries
          .map((e) => ('Damage ${e.key + 1}', e.value)),
    ];

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
                  request.pickupLocation,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _coloredStatusPill(
                context,
                request.status,
                _statusLabel(request.status, strings),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            request.destination,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: _mutedColor(context)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  context,
                  title: 'date',
                  value: completedDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  context,
                  title: 'distance',
                  value: distanceText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  context,
                  title: 'fare',
                  value: fareText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  context,
                  title: 'vehicle',
                  value:
                      request.vehicleType.isEmpty ? '--' : request.vehicleType,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  context,
                  title: 'plate',
                  value: request.licensePlate ?? '--',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  context,
                  title: 'eta',
                  value: etaText,
                ),
              ),
            ],
          ),
          if (request.details.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Details: ${request.details}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Photos',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _mutedColor(context),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final photo = photos[i];
                  return _historyPhotoTile(
                    context,
                    label: photo.$1,
                    url: _pocketBaseService.towRequestFileUrl(
                      request.id,
                      photo.$2,
                    ),
                  );
                },
              ),
            ),
          ],
          if (request.rated) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  'Rated by customer',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _mutedColor(context),
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyPhotoTile(
    BuildContext context, {
    required String label,
    required String url,
  }) {
    return GestureDetector(
      onTap: url.isEmpty ? null : () => _openPhotoViewer(context, url, label),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Container(
              width: 88,
              height: 88,
              color: _isDark(context)
                  ? const Color(0xFF101827)
                  : const Color(0xFFEFF1F5),
              child: url.isEmpty
                  ? Icon(Icons.image_not_supported, color: _mutedColor(context))
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: _mutedColor(context),
                      ),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsCard(BuildContext context) {
    final hasRatings = _myRatings.isNotEmpty;
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
              const Icon(Icons.star, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'My Ratings',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                hasRatings
                    ? '${_myAverageRating.toStringAsFixed(1)} (${_myRatings.length})'
                    : '--',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Stars and feedback left by customers after completed jobs.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
          const SizedBox(height: 12),
          if (!hasRatings)
            _buildEmptyCard(
              context,
              message: 'No ratings received yet.',
            )
          else
            ..._myRatings.take(10).map((rating) {
              final stars = rating.getIntValue('stars');
              final comment = rating.getStringValue('comment').trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isDark(context)
                        ? _kDriverNavy
                        : const Color(0xFFF7F7FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < stars ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          comment,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDriverProfileCard(BuildContext context) {
    final plate = _licensePlateController.text.trim();
    final hasPlate = plate.isNotEmpty;
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
              Icon(Icons.directions_car_filled,
                  color: _kDriverYellow, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vehicle Plate',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Save your tow truck plate. Customers see it after you accept a job.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasPlate
                  ? _kDriverYellow.withValues(alpha: 0.16)
                  : (_isDark(context) ? _kDriverNavy : const Color(0xFFF7F7FB)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasPlate ? _kDriverYellow : _borderColor(context),
                width: hasPlate ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasPlate
                      ? Icons.confirmation_number
                      : Icons.confirmation_number_outlined,
                  color: hasPlate ? _kDriverYellow : _mutedColor(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasPlate ? plate : 'No plate scanned yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: hasPlate
                              ? (_isDark(context) ? Colors.white : _kDriverNavy)
                              : _mutedColor(context),
                        ),
                  ),
                ),
                if (hasPlate)
                  IconButton(
                    tooltip: 'Clear plate',
                    icon: const Icon(Icons.close),
                    onPressed: _isScanningPlate || _isSaving
                        ? null
                        : () async {
                            setState(() {
                              _licensePlateController.text = '';
                            });
                            await _saveDriverProfile(silent: true);
                          },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isScanningPlate || _isSaving ? null : _scanPlate,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kDriverYellow,
                    foregroundColor: _kDriverNavy,
                  ),
                  icon: _isScanningPlate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kDriverNavy,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    _isScanningPlate ? 'Scanning...' : 'Scan Truck Plate',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Pick from gallery',
                onPressed: _isScanningPlate || _isSaving
                    ? null
                    : () => _scanPlate(fromGallery: true),
                icon: const Icon(Icons.photo_library_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _isAvailable,
            contentPadding: EdgeInsets.zero,
            title: Text(
              _isAvailable ? 'Online — accepting jobs' : 'Offline — paused',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            subtitle: Text(
              _isAvailable
                  ? 'Live location is shared with active customers.'
                  : 'Background tracking stopped. Toggle on to receive jobs.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedColor(context),
                  ),
            ),
            onChanged: (value) async {
              setState(() => _isAvailable = value);
              if (value) {
                await DriverLocationService.instance.start();
                await _refreshDriverLocation();
              } else {
                await DriverLocationService.instance.stop();
                try {
                  final name = _driverNameController.text.trim();
                  if (name.isNotEmpty) {
                    await _pocketBaseService.upsertCurrentDriverProfile(
                      driverName: name,
                      isAvailable: false,
                    );
                  }
                } catch (_) {}
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _scanPlate({bool fromGallery = false}) async {
    if (_isScanningPlate) return;
    setState(() {
      _isScanningPlate = true;
    });

    TextRecognizer? recognizer;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 92,
        maxWidth: 1920,
      );
      if (picked == null) {
        if (mounted) setState(() => _isScanningPlate = false);
        return;
      }

      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result =
          await recognizer.processImage(InputImage.fromFilePath(picked.path));

      final plate = _extractPlateFromText(result.text);
      if (!mounted) return;

      if (plate.isEmpty) {
        if (!mounted) return;
        setState(() => _isScanningPlate = false);
        final manual = await _confirmPlate(initial: '', detected: false);
        if (manual == null || manual.isEmpty) return;
        setState(() {
          _licensePlateController.text = manual;
        });
        await _saveDriverProfile(silent: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plate saved: $manual')),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _isScanningPlate = false);
      final confirmed = await _confirmPlate(initial: plate, detected: true);
      if (confirmed == null || confirmed.isEmpty) return;
      setState(() {
        _licensePlateController.text = confirmed;
      });
      await _saveDriverProfile(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plate saved: $confirmed')),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plate scan failed: $e')),
      );
    } finally {
      await recognizer?.close();
      if (mounted) {
        setState(() => _isScanningPlate = false);
      }
    }
  }

  Future<String?> _confirmPlate({
    required String initial,
    required bool detected,
  }) async {
    final controller = TextEditingController(text: initial);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(detected ? 'Confirm plate' : 'Enter plate manually'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detected
                    ? 'Edit if OCR misread it. Plates usually contain letters and digits.'
                    : 'OCR could not detect a plate. Type your truck plate.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 12,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'License plate',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final v = (value ?? '').trim().toUpperCase();
                  if (v.length < 3) return 'Too short';
                  if (RegExp(r'^\d{8}$').hasMatch(v)) {
                    return 'Looks like a phone number, not a plate';
                  }
                  if (!RegExp(r'^[A-Z0-9 \-]+$').hasMatch(v)) {
                    return 'Use letters, digits, space or dash only';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          if (detected)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('__rescan__'),
              child: const Text('Re-scan'),
            ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(ctx).pop(controller.text.trim().toUpperCase());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == '__rescan__') {
      await _scanPlate();
      return null;
    }
    return result;
  }

  String _extractPlateFromText(String raw) {
    if (raw.trim().isEmpty) return '';
    final tokens = raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9\s\-]'), ' ')
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll('-', '').trim())
        .where((t) => t.length >= 3 && t.length <= 10)
        .where((t) => RegExp(r'\d').hasMatch(t))
        .where((t) => RegExp(r'^[A-Z0-9]+$').hasMatch(t))
        .toList();
    if (tokens.isEmpty) return '';

    int score(String t) {
      final digits = RegExp(r'\d').allMatches(t).length;
      final letters = RegExp(r'[A-Z]').allMatches(t).length;
      return digits * 2 + letters + t.length;
    }

    tokens.sort((a, b) => score(b).compareTo(score(a)));
    return tokens.first;
  }

  Future<void> _refreshDriverLocation() async {
    if (!_isAvailable) {
      return;
    }
    try {
      final place = await LocationService.tryGetCurrentPlaceSilently();
      if (!mounted || place == null) return;
      final prev = _driverLivePlace;
      setState(() {
        _driverLivePlace = place;
      });
      // Trigger route refresh when driver moves enough or there is no route yet.
      final movedFar = prev == null ||
          BahrainMapService.distanceMeters(
                prev.latitude,
                prev.longitude,
                place.latitude,
                place.longitude,
              ) >=
              200;
      if (movedFar && _focusedRequest != null) {
        _lastMapSignature = '';
        _syncFocusedRequestMap();
      }
      final driverName = _driverNameController.text.trim();
      if (driverName.isEmpty) return;
      try {
        await _pocketBaseService.upsertCurrentDriverProfile(
          driverName: driverName,
          driverPhone: _resolveOwnPhone(),
          driverLat: place.latitude,
          driverLng: place.longitude,
          isAvailable: true,
        );
      } catch (_) {
        // non-fatal: profile collection or rules may block writes
      }
      try {
        final completedAny =
            await _pocketBaseService.pushDriverLocationToActiveRequests(
          latitude: place.latitude,
          longitude: place.longitude,
          driverName: driverName,
        );
        if (completedAny && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip completed automatically at destination.'),
            ),
          );
          await _loadRequests(silent: true);
        }
      } catch (_) {
        // non-fatal: keeps user marker stale but does not break the app
      }
    } catch (_) {
      // location may be temporarily unavailable; ignore
    }
  }

  Future<void> _loadDriverRatings() async {
    final userId = _pocketBaseService.currentUserRecord?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        _pocketBaseService.getRatingsForDriver(userId, limit: 50),
        _pocketBaseService.getDriverAverageRating(userId),
      ]);
      if (!mounted) return;
      setState(() {
        _myRatings = results[0] as List<RecordModel>;
        _myAverageRating = results[1] as double;
      });
    } catch (_) {
      // ratings collection may not exist yet; keep old state
    }
  }

  Widget _buildLiveMapCard(BuildContext context, AppStrings strings) {
    final focused = _focusedRequest;
    final hasDriverLoc = _driverLivePlace != null;
    final mapSubline = _isLoadingMap
        ? 'Loading customer location...'
        : (focused == null
            ? (hasDriverLoc
                ? 'You are on the map. Awaiting requests.'
                : 'No pending or active request to display.')
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
                  'Live Tracking',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh my location',
                icon: const Icon(Icons.my_location, size: 20),
                onPressed: _refreshDriverLocation,
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
            focused == null
                ? 'Your truck location is shown here. Tap Track on a job to focus its route.'
                : 'Showing this job route for the driver.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                BarqLiveMap(
                  height: 280,
                  pickup: _focusedPickupPlace,
                  destination: _focusedDestinationPlace,
                  driver: _driverLivePlace,
                  routePoints: _focusedRouteInfo?.points ?? const [],
                  headline: focused == null
                      ? 'Your live position'
                      : 'Customer pickup -> destination',
                  subline: mapSubline,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Fullscreen map',
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      onPressed: () => _openFullscreenMap(focused, mapSubline),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legendDot(const Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text('You', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFF16A34A)),
              const SizedBox(width: 4),
              Text('Customer', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFDC2626)),
              const SizedBox(width: 4),
              Text('Destination',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
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
                  _coloredStatusPill(context, request.status, statusLabel),
                ],
              ),
              const SizedBox(height: 10),
              _kvLine(context, Icons.local_shipping_outlined, 'Vehicle',
                  request.vehicleType),
              _kvLine(context, Icons.schedule_outlined, 'Timing',
                  request.serviceTiming),
              if ((request.driverName ?? '').isNotEmpty)
                _kvLine(context, Icons.person_outline, 'Driver',
                    request.driverName!),
              if ((request.licensePlate ?? '').isNotEmpty)
                _kvLine(context, Icons.confirmation_number_outlined, 'Plate',
                    request.licensePlate!),
              if (request.details.trim().isNotEmpty)
                _kvLine(context, Icons.notes_outlined, 'Notes',
                    request.details.trim()),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metricTile(
                      context,
                      title: 'ETA',
                      value: etaText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile(
                      context,
                      title: 'Distance',
                      value: distanceText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile(
                      context,
                      title: 'Fare',
                      value: fareText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRequestActions(
                context,
                request: request,
                isPending: isPending,
              ),
              if (request.status == 'assigned' ||
                  request.status == 'en_route') ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : () => _promptCancel(request),
                    icon: const Icon(Icons.cancel_outlined,
                        color: Colors.red, size: 18),
                    label: const Text(
                      'Cancel job',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
              if (request.status == 'assigned' ||
                  request.status == 'en_route' ||
                  request.status == 'completed') ...[
                const SizedBox(height: 10),
                _buildPhotoStrip(request),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoStrip(TowRequest request) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _photoChip(
          label: request.pickupPhoto == null ? 'Pickup photo' : 'Pickup ✓',
          uploaded: request.pickupPhoto != null,
          onTap: () => _capturePhoto(request, 'pickup_photo'),
        ),
        _photoChip(
          label: request.dropoffPhoto == null ? 'Dropoff photo' : 'Dropoff ✓',
          uploaded: request.dropoffPhoto != null,
          onTap: () => _capturePhoto(request, 'dropoff_photo'),
        ),
        _photoChip(
          label: 'Damage (${request.damagePhotos.length}/5)',
          uploaded: request.damagePhotos.isNotEmpty,
          onTap: request.damagePhotos.length >= 5
              ? null
              : () => _capturePhoto(request, 'damage_photos'),
        ),
      ],
    );
  }

  Widget _kvLine(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _mutedColor(context)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoChip({
    required String label,
    required bool uploaded,
    VoidCallback? onTap,
  }) {
    return ActionChip(
      avatar: Icon(
        uploaded ? Icons.check_circle : Icons.add_a_photo_outlined,
        size: 18,
        color: uploaded ? Colors.green : null,
      ),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Future<void> _capturePhoto(TowRequest request, String fieldName) async {
    if (_isSaving) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      setState(() => _isSaving = true);

      await _pocketBaseService.uploadTowRequestPhoto(
        requestId: request.id,
        fieldName: fieldName,
        filePath: picked.path,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fieldName uploaded')),
      );
      await _loadRequests(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildPrimaryAction({
    required TowRequest request,
    required bool isPending,
  }) {
    if (isPending) {
      return FilledButton.icon(
        onPressed: _isSaving ? null : () => _acceptRequest(request),
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('Accept & track', overflow: TextOverflow.ellipsis),
      );
    }

    if (request.status == 'cancel_pending') {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
        label: const Text('AI reviewing...'),
      );
    }

    if (request.status == 'assigned') {
      return FilledButton.icon(
        onPressed: _isSaving ? null : () => _startTrip(request),
        icon: const Icon(Icons.directions_car_filled_outlined, size: 18),
        label: const Text('Start at pickup', overflow: TextOverflow.ellipsis),
      );
    }

    return OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.location_on_outlined, size: 18),
      label: const Text(
        'Auto-completes at destination',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRequestActions(
    BuildContext context, {
    required TowRequest request,
    required bool isPending,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final twoColumn = constraints.maxWidth >= 330;
        final halfWidth =
            twoColumn ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;

        Widget sized(double width, Widget child) {
          return SizedBox(
            width: width,
            height: 48,
            child: child,
          );
        }

        if (isPending) {
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              sized(
                halfWidth,
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _declineRequest(request),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text(
                    'Decline',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
              sized(
                halfWidth,
                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _acceptRequest(request),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text(
                    'Accept & track',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          );
        }

        final primary = _buildPrimaryAction(
          request: request,
          isPending: isPending,
        );
        final primaryWidth =
            request.status == 'en_route' ? constraints.maxWidth : halfWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            sized(
              request.status == 'en_route' ? constraints.maxWidth : halfWidth,
              OutlinedButton.icon(
                onPressed: () => _openTracking(request),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text(
                  'Track',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            sized(primaryWidth, primary),
          ],
        );
      },
    );
  }

  Future<void> _promptCancel(TowRequest request) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you cancelling? AI will review the reason. '
              'Frivolous cancellations may impact your account.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'e.g. Vehicle breakdown on the way',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Keep job'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Submit cancel'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.length < 5) return;
    await _submitCancellation(request, reason);
  }

  Future<void> _submitCancellation(TowRequest request, String reason) async {
    setState(() {
      _isSaving = true;
    });
    final previousStatus = request.status;
    try {
      await _pocketBaseService.requestDriverCancellation(
        requestId: request.id,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation sent. AI reviewing...')),
      );
      await _loadRequests(silent: true);
      _runCancellationAi(request, reason, previousStatus);
    } on ClientException catch (e) {
      if (!mounted) return;
      final message =
          e.response['message'] as String? ?? 'Could not request cancellation.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request cancellation: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _runCancellationAi(
    TowRequest request,
    String reason,
    String previousStatus,
  ) async {
    try {
      final verdict =
          await ModerationAiService.instance.reviewDriverCancellation(
        reason: reason,
        pickupLocation: request.pickupLocation,
        destination: request.destination,
        currentStatus: previousStatus,
      );
      await _pocketBaseService.applyDriverCancellationVerdict(
        requestId: request.id,
        decision: verdict.decision,
        reasoning: verdict.reasoning,
        confidence: verdict.confidence,
        previousStatus: previousStatus,
      );
      if (!mounted) return;
      final label = switch (verdict.decision) {
        'approved' => 'AI approved cancellation.',
        'rejected' => 'AI rejected cancellation. Job restored.',
        _ => 'AI flagged for human review.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(label)));
      await _loadRequests(silent: true);
    } catch (_) {
      // best-effort: an admin can finalise manually if AI unavailable
    }
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
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

class _FullscreenMapPage extends StatelessWidget {
  const _FullscreenMapPage({
    this.pickup,
    this.destination,
    this.driver,
    this.routePoints = const <LatLng>[],
    this.headline,
    this.subline,
  });

  final PlaceResult? pickup;
  final PlaceResult? destination;
  final PlaceResult? driver;
  final List<LatLng> routePoints;
  final String? headline;
  final String? subline;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live map'),
        leading: IconButton(
          icon: const Icon(Icons.fullscreen_exit),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Exit fullscreen',
        ),
      ),
      body: BarqLiveMap(
        height: size.height,
        pickup: pickup,
        destination: destination,
        driver: driver,
        routePoints: routePoints,
        headline: headline,
        subline: subline,
      ),
    );
  }
}
