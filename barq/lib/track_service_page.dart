import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/place_result.dart';
import 'models/tow_request_model.dart';
import 'services/bahrain_map_service.dart';
import 'services/pocketbase_service.dart';
import 'settings.dart';
import 'widgets/barq_live_map.dart';

class _RoutePlan {
  const _RoutePlan(this.start, this.end, {required this.leg});

  final LatLng start;
  final LatLng end;
  final String leg;
}

const Color _kBarqYellow = Color(0xFFF4C21E);
const Color _kBarqNavy = Color(0xFF0B1220);
const Color _kBarqSoftDark = Color(0xFF1A2336);
const Color _kBarqSoftLight = Color(0xFFEFF1F5);
const Color _kBarqFieldDark = Color(0xFF101827);
const Color _kBarqFieldLight = Color(0xFFF9FAFB);

class TrackServicePage extends StatefulWidget {
  const TrackServicePage({
    super.key,
    this.requestId,
    this.pickupLocation = '',
    this.destinationLocation = '',
    this.driverName = '',
    this.driverRating = 0.0,
    this.driverTotalRides = 0,
    this.vehicleDescription = '',
    this.licensePlate = '',
    this.distanceKm = 0.0,
    this.remainingDistanceKm = 0.0,
    this.etaMinutes = 0,
    this.baseFare = 0.0,
    this.distanceFare = 0.0,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.driverLat,
    this.driverLng,
    required this.language,
  });

  final String? requestId;
  final String pickupLocation;
  final String destinationLocation;
  final String driverName;
  final double driverRating;
  final int driverTotalRides;
  final String vehicleDescription;
  final String licensePlate;
  final double distanceKm;
  final double remainingDistanceKm;
  final int etaMinutes;
  final double baseFare;
  final double distanceFare;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? driverLat;
  final double? driverLng;
  final AppLanguage language;

  @override
  State<TrackServicePage> createState() => _TrackServicePageState();
}

class _TrackServicePageState extends State<TrackServicePage> {
  final PocketBaseService _pocketBaseService = PocketBaseService.instance;

  late String _driverName;
  late double _driverRating;
  late int _driverTotalRides;
  late String _vehicleDescription;
  late String _licensePlate;
  late double _distanceKm;
  late double _remainingDistanceKm;
  late int _etaMinutes;
  late double _baseFare;
  late double _distanceFare;
  late String _pickupLocation;
  late String _destinationLocation;
  late double? _pickupLat;
  late double? _pickupLng;
  late double? _destinationLat;
  late double? _destinationLng;
  late double? _driverLat;
  late double? _driverLng;

  String _status = 'pending';
  String? _driverPhone;
  String? _driverUserId;
  DateTime? _lastDriverUpdate;
  bool _loadingMap = true;
  bool _loadingRequest = false;
  bool _realtimeReady = false;
  bool _callingDriver = false;
  String? _requestNotice;
  String? _mapNotice;
  int _mapHydrationToken = 0;
  Timer? _pollTimer;
  Timer? _uiTicker;

  PlaceResult? _pickupPlace;
  PlaceResult? _destinationPlace;
  PlaceResult? _driverPlace;
  RouteInfo? _routeInfo;
  LatLng? _lastRouteStart;
  String? _lastRouteLeg;
  static const double _kRouteRebuildMeters = 200.0;

  AppLanguage get _language => widget.language;

  bool get _isArabic => _language == AppLanguage.ar;

  double get _totalFare => _baseFare + _distanceFare;

  double get _displayDistanceKm {
    final routeDistance = _routeInfo?.distanceKm;
    if (routeDistance != null && routeDistance > 0) {
      return routeDistance;
    }
    return _distanceKm;
  }

  int get _displayEtaMinutes {
    final routeEta = _routeInfo?.durationMinutes;
    if (_etaMinutes > 0) {
      return _etaMinutes;
    }
    return routeEta ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _driverName = widget.driverName;
    _driverRating = widget.driverRating;
    _driverTotalRides = widget.driverTotalRides;
    _vehicleDescription = widget.vehicleDescription;
    _licensePlate = widget.licensePlate;
    _distanceKm = widget.distanceKm;
    _remainingDistanceKm = widget.remainingDistanceKm;
    _etaMinutes = widget.etaMinutes;
    _baseFare = widget.baseFare;
    _distanceFare = widget.distanceFare;
    _pickupLocation = widget.pickupLocation;
    _destinationLocation = widget.destinationLocation;
    _pickupLat = widget.pickupLat;
    _pickupLng = widget.pickupLng;
    _destinationLat = widget.destinationLat;
    _destinationLng = widget.destinationLng;
    _driverLat = widget.driverLat;
    _driverLng = widget.driverLng;

    _hydrateMap();
    if (widget.requestId != null) {
      _loadLatestRequest(showLoader: true);
      _subscribeToUpdates();
      _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _loadLatestRequest(silent: true);
      });
    }
    _uiTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _uiTicker?.cancel();
    if (widget.requestId != null) {
      _pocketBaseService.unsubscribeTowRequest(widget.requestId!);
    }
    super.dispose();
  }

  Future<void> _loadLatestRequest({
    bool showLoader = false,
    bool silent = false,
  }) async {
    if (showLoader && !silent && mounted) {
      setState(() {
        _loadingRequest = true;
      });
    }
    try {
      final latest = await _pocketBaseService.getTowRequest(widget.requestId!);
      if (!mounted) {
        return;
      }
      setState(() {
        _requestNotice = null;
      });
      _applyTowRequestUpdate(latest, refreshMap: true);
    } catch (_) {
      if (!mounted || silent) {
        return;
      }
      setState(() {
        _requestNotice =
            'Could not load latest request data. Pull down to retry.';
      });
    } finally {
      if (mounted && showLoader && !silent) {
        setState(() {
          _loadingRequest = false;
        });
      }
    }
  }

  Future<void> _subscribeToUpdates() async {
    try {
      await _pocketBaseService.subscribeTowRequest(
        widget.requestId!,
        (updated) {
          if (!mounted) {
            return;
          }
          _applyTowRequestUpdate(updated, refreshMap: true);
        },
      );
      if (mounted) {
        setState(() {
          _realtimeReady = true;
          _requestNotice = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _realtimeReady = false;
          _requestNotice =
              'Realtime connection is unavailable. Showing latest synced data.';
        });
      }
    }
  }

  void _applyTowRequestUpdate(
    TowRequest request, {
    required bool refreshMap,
  }) {
    final previousDriverLat = _driverLat;
    final previousDriverLng = _driverLng;
    final hasFreshDriverLocation =
        request.driverLat != null && request.driverLng != null;
    final driverLocationChanged = hasFreshDriverLocation &&
        (request.driverLat != previousDriverLat ||
            request.driverLng != previousDriverLng);

    setState(() {
      _driverName = _normalizedText(request.driverName) ?? _driverName;
      _driverRating = request.driverRating ?? _driverRating;
      _driverTotalRides = request.driverTotalRides ?? _driverTotalRides;
      _vehicleDescription = request.vehicleType;
      _licensePlate = _normalizedText(request.licensePlate) ?? _licensePlate;
      _distanceKm = request.distanceKm ?? _distanceKm;
      _remainingDistanceKm = request.distanceKm ?? _remainingDistanceKm;
      _etaMinutes = request.etaMinutes ?? _etaMinutes;
      _baseFare = request.baseFare ?? _baseFare;
      _distanceFare = request.distanceFare ?? _distanceFare;
      _pickupLocation = request.pickupLocation;
      _destinationLocation = request.destination;
      _status = request.status;
      _pickupLat = request.pickupLat ?? _pickupLat;
      _pickupLng = request.pickupLng ?? _pickupLng;
      _destinationLat = request.destinationLat ?? _destinationLat;
      _destinationLng = request.destinationLng ?? _destinationLng;
      _driverLat = request.driverLat ?? _driverLat;
      _driverLng = request.driverLng ?? _driverLng;
      _driverPhone = request.driverPhone ?? _driverPhone;
      _driverUserId = request.driverUserId ?? _driverUserId;
      if (driverLocationChanged) {
        _lastDriverUpdate = DateTime.now();
        _driverPlace = _driverPlaceFromCoordinates();
      }
      if (_status == 'completed' || _status == 'cancelled') {
        _remainingDistanceKm = 0;
      }
    });

    if (refreshMap) {
      _hydrateMap(
        showLoader: !driverLocationChanged ||
            _pickupPlace == null ||
            _destinationPlace == null,
      );
    }
  }

  String? _normalizedText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  PlaceResult? _driverPlaceFromCoordinates() {
    if (_driverLat == null || _driverLng == null) {
      return null;
    }
    return PlaceResult(
      title: _driverName.isEmpty ? _driverLabel : _driverName,
      subtitle: _driverMarkerSubtitle,
      latitude: _driverLat!,
      longitude: _driverLng!,
    );
  }

  Future<void> _hydrateMap({bool showLoader = true}) async {
    if (!mounted) {
      return;
    }

    final token = ++_mapHydrationToken;
    if (showLoader) {
      setState(() {
        _loadingMap = true;
        _mapNotice = null;
      });
    }

    final pickup = await _resolvePlace(
      label: _pickupLocation,
      latitude: _pickupLat,
      longitude: _pickupLng,
    );
    final destination = await _resolvePlace(
      label: _destinationLocation,
      latitude: _destinationLat,
      longitude: _destinationLng,
    );

    PlaceResult? driver;
    driver = _driverPlaceFromCoordinates();

    final routePlan = _selectRoutePlan(
      pickup: pickup,
      destination: destination,
      driver: driver,
    );
    RouteInfo? route = _routeInfo;
    if (routePlan != null) {
      final shouldRebuild = _shouldRebuildRoute(routePlan);
      if (shouldRebuild || route == null) {
        try {
          route = await BahrainMapService.buildRoute(
            start: routePlan.start,
            end: routePlan.end,
          );
          _lastRouteStart = routePlan.start;
          _lastRouteLeg = routePlan.leg;
        } catch (_) {
          route = null;
        }
      }
    } else {
      route = null;
      _lastRouteStart = null;
      _lastRouteLeg = null;
    }

    if (!mounted || token != _mapHydrationToken) {
      return;
    }

    setState(() {
      _pickupPlace = pickup;
      _destinationPlace = destination;
      _driverPlace = driver;
      _routeInfo = route;
      _loadingMap = false;
      _mapNotice = _buildMapNotice(
        pickup: pickup,
        destination: destination,
        route: route,
        driver: driver,
      );
    });
  }

  bool _shouldRebuildRoute(_RoutePlan plan) {
    if (_lastRouteLeg != plan.leg) return true;
    final last = _lastRouteStart;
    if (last == null) return true;
    final meters = BahrainMapService.distanceMeters(
      last.latitude,
      last.longitude,
      plan.start.latitude,
      plan.start.longitude,
    );
    return meters >= _kRouteRebuildMeters;
  }

  double? _liveDriverDistanceKm() {
    if (_driverLat == null || _driverLng == null) return null;
    if (_status == 'en_route' &&
        _destinationLat != null &&
        _destinationLng != null) {
      return BahrainMapService.distanceMeters(
              _driverLat!, _driverLng!, _destinationLat!, _destinationLng!) /
          1000.0;
    }
    if (_pickupLat != null && _pickupLng != null) {
      return BahrainMapService.distanceMeters(
              _driverLat!, _driverLng!, _pickupLat!, _pickupLng!) /
          1000.0;
    }
    return null;
  }

  _RoutePlan? _selectRoutePlan({
    required PlaceResult? pickup,
    required PlaceResult? destination,
    required PlaceResult? driver,
  }) {
    if (driver != null && destination != null && _status == 'en_route') {
      return _RoutePlan(driver.latLng, destination.latLng,
          leg: 'to_destination');
    }
    if (driver != null && pickup != null && _status == 'assigned') {
      return _RoutePlan(driver.latLng, pickup.latLng, leg: 'to_pickup');
    }
    if (pickup != null && destination != null) {
      return _RoutePlan(pickup.latLng, destination.latLng, leg: 'preview');
    }
    return null;
  }

  Future<PlaceResult?> _resolvePlace({
    required String label,
    required double? latitude,
    required double? longitude,
  }) async {
    final cleanLabel = label.trim();
    if (latitude != null && longitude != null) {
      final title = _titleFromLabel(cleanLabel);
      final subtitle = _subtitleFromLabel(cleanLabel);
      return PlaceResult(
        title: title,
        subtitle: subtitle,
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
      return _isArabic ? 'موقع' : 'Location';
    }
    return clean.split(',').first.trim();
  }

  String _subtitleFromLabel(String label) {
    final clean = label.trim();
    if (clean.isEmpty || !clean.contains(',')) {
      return '';
    }
    final parts = clean.split(',').map((item) => item.trim()).toList();
    if (parts.length <= 1) {
      return '';
    }
    return parts.sublist(1).join(' • ');
  }

  String? _buildMapNotice({
    required PlaceResult? pickup,
    required PlaceResult? destination,
    required RouteInfo? route,
    required PlaceResult? driver,
  }) {
    if ((pickup == null || destination == null) && route == null) {
      return _isArabic
          ? 'تعذر تحديد مواقع الطلب بدقة على خريطة البحرين.'
          : 'The pickup or destination could not be resolved on the Bahrain map.';
    }

    if (route == null) {
      return _isArabic
          ? 'تم عرض المواقع، لكن تعذر تحميل المسار الآن.'
          : 'The locations are shown, but the driving route could not be loaded right now.';
    }

    if (driver == null && _status != 'pending' && _status != 'cancelled') {
      return _isArabic
          ? 'سيظهر موقع السائق مباشرة عند تحديث حقلي driver_lat و driver_lng في PocketBase.'
          : 'The driver marker appears automatically when driver_lat and driver_lng are updated in PocketBase.';
    }

    return null;
  }

  String get _driverLabel => _isArabic ? 'السائق' : 'Driver';

  String get _driverMarkerSubtitle =>
      _isArabic ? 'موقع السائق الحالي' : 'Current driver location';

  String get _refreshLabel => _isArabic ? 'تحديث' : 'Refresh';

  String get _lastUpdateLabel {
    final liveKm = _liveDriverDistanceKm();
    final stamp = _lastDriverUpdate;
    if (stamp == null) {
      if (_realtimeReady) {
        return _isArabic ? 'بانتظار موقع السائق' : 'Waiting for driver fix';
      }
      return _realtimeFallbackLabel;
    }
    final delta = DateTime.now().difference(stamp);
    final ageLabel = delta.inSeconds < 5
        ? (_isArabic ? 'الآن' : 'now')
        : delta.inSeconds < 60
            ? (_isArabic
                ? 'قبل ${delta.inSeconds} ثانية'
                : '${delta.inSeconds}s ago')
            : delta.inMinutes < 60
                ? (_isArabic
                    ? 'قبل ${delta.inMinutes} دقيقة'
                    : '${delta.inMinutes} min ago')
                : (_isArabic
                    ? 'قبل ${delta.inHours} ساعة'
                    : '${delta.inHours}h ago');
    if (liveKm != null) {
      final target = _status == 'en_route'
          ? (_isArabic ? 'الوجهة' : 'destination')
          : (_isArabic ? 'الالتقاط' : 'pickup');
      final distance = liveKm < 1
          ? '${(liveKm * 1000).round()} m'
          : '${liveKm.toStringAsFixed(1)} km';
      return _isArabic
          ? '$distance من $target • $ageLabel'
          : '$distance to $target • $ageLabel';
    }
    return ageLabel;
  }

  String get _realtimeFallbackLabel => _isArabic
      ? 'يعرض التطبيق آخر بيانات متاحة من PocketBase.'
      : 'Showing the latest available PocketBase data.';

  String get _callUnavailableLabel => _isArabic
      ? 'أضف رقم هاتف السائق في قاعدة البيانات لتفعيل الاتصال المباشر.'
      : 'Store the driver phone number in the database to enable direct calling.';

  String get _mapHeadline {
    if (_status == 'completed') {
      return _isArabic ? 'تمت الخدمة' : 'Service completed';
    }
    if (_status == 'cancelled') {
      return _isArabic ? 'تم إلغاء الطلب' : 'Request cancelled';
    }
    if (_status == 'cancel_pending') {
      return _isArabic
          ? 'مراجعة طلب الإلغاء'
          : 'Cancellation under review';
    }
    if (_status == 'expired') {
      return _isArabic ? 'انتهت صلاحية الطلب' : 'Request expired';
    }
    if (_status == 'en_route' && _driverPlace != null) {
      return _isArabic ? 'في الطريق إلى الوجهة' : 'Heading to destination';
    }
    if (_status == 'assigned' && _driverPlace != null) {
      return _isArabic ? 'السائق قادم إليك' : 'Driver heading to pickup';
    }
    if (_driverPlace != null) {
      return _isArabic ? 'تتبع مباشر داخل البحرين' : 'Live Bahrain tracking';
    }
    return _isArabic ? 'خريطة الخدمة في البحرين' : 'Bahrain service map';
  }

  String get _mapSubline {
    final distance = _displayDistanceKm;
    final eta = _displayEtaMinutes;
    final pieces = <String>[];
    if (distance > 0) {
      pieces.add(
        _isArabic
            ? '${distance.toStringAsFixed(1)} كم'
            : '${distance.toStringAsFixed(1)} km',
      );
    }
    if (eta > 0 &&
        _status != 'completed' &&
        _status != 'cancelled' &&
        _status != 'expired' &&
        _status != 'cancel_pending') {
      pieces.add(
        _isArabic ? 'حوالي $eta دقيقة' : 'about $eta min',
      );
    }
    if (pieces.isNotEmpty) {
      return pieces.join(' • ');
    }
    return AppStrings(_language).text('realtimeTrackingSub');
  }

  int get _statusStep {
    switch (_status) {
      case 'assigned':
        return 1;
      case 'en_route':
        return 2;
      case 'completed':
        return 3;
      case 'cancel_pending':
      case 'cancelled':
      case 'expired':
      default:
        return 0;
    }
  }

  String _statusLabel(AppStrings strings) {
    switch (_status) {
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
      case 'cancel_pending':
        return _isArabic ? 'طلب إلغاء قيد المراجعة' : 'Cancellation pending';
      case 'expired':
        return _isArabic ? 'منتهي الصلاحية' : 'Expired';
      default:
        return _status;
    }
  }

  String _statusDescription(AppStrings strings) {
    switch (_status) {
      case 'pending':
        return strings.text('serviceProgressRequested');
      case 'assigned':
        return strings.text('serviceProgressAssigned');
      case 'en_route':
        return strings.text('trackDriverOnTheWay');
      case 'completed':
        return _isArabic
            ? 'تم الوصول وإنهاء الخدمة بنجاح.'
            : 'The truck arrived and the service was completed successfully.';
      case 'cancelled':
        return _isArabic
            ? 'تم إلغاء الطلب في قاعدة البيانات.'
            : 'This request was cancelled in the database.';
      case 'cancel_pending':
        return _isArabic
            ? 'تتم مراجعة طلب الإلغاء من قبل النظام.'
            : 'Your cancellation request is under review.';
      case 'expired':
        return _isArabic
            ? 'انتهت صلاحية الطلب قبل قبول أي سائق.'
            : 'The request expired before any driver accepted it.';
      default:
        return strings.text('realtimeTrackingSub');
    }
  }

  bool _isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color _softSurface(BuildContext context) {
    return _isDark(context) ? _kBarqSoftDark : _kBarqSoftLight;
  }

  Color _fieldSurface(BuildContext context) {
    return _isDark(context) ? _kBarqFieldDark : _kBarqFieldLight;
  }

  Future<void> _callDriver() async {
    if (_callingDriver) return;
    setState(() => _callingDriver = true);
    try {
      var phone = _driverPhone?.trim();
      if (phone == null || phone.isEmpty) {
        phone = await _pocketBaseService.resolveDriverPhone(
          driverUserId: _driverUserId,
          driverName: _driverName,
        );
      }
      if (!mounted) return;
      if (phone == null || phone.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_callUnavailableLabel)),
        );
        return;
      }
      final sanitized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      final uri = Uri(scheme: 'tel', path: sanitized);
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isArabic
                  ? 'تعذر فتح تطبيق الاتصال. الرقم: $sanitized'
                  : 'Could not open dialer. Number: $sanitized')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _callingDriver = false);
    }
  }

  Future<void> _refreshPage() async {
    if (widget.requestId != null) {
      await _loadLatestRequest(showLoader: true);
    } else {
      await _hydrateMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_language);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.text('trackService'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              strings.text('realtimeTrackingSub'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _refreshLabel,
            onPressed: _loadingRequest ? null : _refreshPage,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_loadingRequest)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (_requestNotice != null) ...[
              _noticeCard(context, _requestNotice!),
              const SizedBox(height: 12),
            ],
            BarqLiveMap(
              height: 300,
              pickup: _pickupPlace,
              destination: _destinationPlace,
              driver: _driverPlace,
              routePoints: _routeInfo?.points ?? const [],
              headline: _mapHeadline,
              subline: _loadingMap
                  ? (_isArabic ? 'جاري تحميل الخريطة...' : 'Loading map...')
                  : _mapSubline,
            ),
            if (_loadingMap)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (_mapNotice != null) ...[
              const SizedBox(height: 12),
              _noticeCard(context, _mapNotice!),
            ],
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: strings.text('serviceProgress'),
              subtitle: _statusDescription(strings),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _progressStepChip(
                          context,
                          label: strings.text('serviceProgressRequested'),
                          active: _statusStep >= 0,
                          done: _statusStep > 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _progressStepChip(
                          context,
                          label: strings.text('serviceProgressAssigned'),
                          active: _statusStep >= 1,
                          done: _statusStep > 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _progressStepChip(
                          context,
                          label: strings.text('serviceProgressEnRoute'),
                          active: _statusStep >= 2,
                          done: _statusStep > 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _infoTile(
                          context,
                          icon: Icons.local_shipping_outlined,
                          label: _isArabic ? 'الحالة' : 'Status',
                          value: _statusLabel(strings),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoTile(
                          context,
                          icon: _lastDriverUpdate == null
                              ? Icons.cloud_outlined
                              : Icons.gps_fixed,
                          label:
                              _isArabic ? 'آخر موقع للسائق' : 'Last driver fix',
                          value: _lastUpdateLabel,
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: strings.text('serviceDetails'),
              subtitle: _isArabic
                  ? 'المواقع والمسافة الحالية داخل البحرين.'
                  : 'Current locations and distance inside Bahrain.',
              child: Column(
                children: [
                  _detailRow(
                    context,
                    icon: Icons.my_location_outlined,
                    title: strings.text('trackPickup'),
                    value: _pickupLocation,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    context,
                    icon: Icons.flag_outlined,
                    title: strings.text('trackDestination'),
                    value: _destinationLocation,
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _infoTile(
                          context,
                          icon: Icons.route_outlined,
                          label: strings.text('distance'),
                          value: _isArabic
                              ? '${_displayDistanceKm.toStringAsFixed(1)} كم'
                              : '${_displayDistanceKm.toStringAsFixed(1)} km',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoTile(
                          context,
                          icon: Icons.schedule_outlined,
                          label: strings.text('eta'),
                          value: _displayEtaMinutes > 0
                              ? (_isArabic
                                  ? '$_displayEtaMinutes دقيقة'
                                  : '$_displayEtaMinutes min')
                              : '--',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: strings.text('trackYourDriver'),
              subtitle: _isArabic
                  ? 'بيانات السائق والمركبة من PocketBase.'
                  : 'Driver and vehicle details from PocketBase.',
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: _kBarqYellow,
                        child: Text(
                          _driverName.isEmpty ? '?' : _driverName[0],
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: _kBarqNavy,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _status == 'assigned' || _status == 'en_route'
                                  ? strings.text('trackDriverOnTheWay')
                                  : _statusDescription(strings),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _infoTile(
                          context,
                          icon: Icons.star_outline,
                          label: _isArabic ? 'التقييم' : 'Rating',
                          value: _driverRating > 0
                              ? _driverRating.toStringAsFixed(1)
                              : '--',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoTile(
                          context,
                          icon: Icons.history_toggle_off,
                          label: _isArabic ? 'الرحلات' : 'Rides',
                          value: '$_driverTotalRides',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    context,
                    icon: Icons.local_shipping_outlined,
                    title: strings.text('trackVehicle'),
                    value: _vehicleDescription,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    context,
                    icon: Icons.badge_outlined,
                    title: strings.text('trackLicensePlate'),
                    value: _licensePlate.trim().isEmpty
                        ? 'Pending'
                        : _licensePlate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: strings.text('trackServiceCost'),
              subtitle: _isArabic
                  ? 'تفصيل التكلفة المحفوظة في قاعدة البيانات.'
                  : 'Cost breakdown saved in the database.',
              child: Column(
                children: [
                  _priceRow(
                    context,
                    label:
                        '${strings.text('estimateBaseFare')} (${_displayDistanceKm.toStringAsFixed(1)} km)',
                    value: _baseFare,
                  ),
                  if (_distanceFare > 0) ...[
                    const SizedBox(height: 10),
                    _priceRow(
                      context,
                      label: _isArabic ? 'رسوم الليل' : 'Night surcharge',
                      value: _distanceFare,
                    ),
                  ],
                  if (_remainingDistanceKm > 0 &&
                      _status != 'completed' &&
                      _status != 'cancelled') ...[
                    const SizedBox(height: 10),
                    _priceRow(
                      context,
                      label:
                          _isArabic ? 'المسافة المتبقية' : 'Remaining distance',
                      valueText: _isArabic
                          ? '${_remainingDistanceKm.toStringAsFixed(1)} كم'
                          : '${_remainingDistanceKm.toStringAsFixed(1)} km',
                    ),
                  ],
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
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: strings.text('trackNeedHelp'),
              subtitle: _isArabic
                  ? 'يمكنك تحديث الحالة أو مراجعة بيانات السائق من PocketBase.'
                  : 'Refresh the request or review the live driver data from PocketBase.',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _refreshPage,
                          icon: const Icon(Icons.refresh),
                          label: Text(_refreshLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _callingDriver ? null : _callDriver,
                          icon: _callingDriver
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.call_outlined),
                          label: Text(strings.text('trackCallDriver')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noticeCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(18),
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

  Widget _progressStepChip(
    BuildContext context, {
    required String label,
    required bool active,
    required bool done,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = done || active
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).hintColor;
    final background = done
        ? primary.withValues(alpha: 0.28)
        : (active ? primary.withValues(alpha: 0.18) : _fieldSurface(context));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done || active
              ? foreground.withValues(alpha: 0.25)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kBarqYellow.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kBarqYellow),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool compact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).hintColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // _RoutePlan kept as a fileprivate class below.

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
                ? (_isDark(context)
                    ? _kBarqYellow
                    : Theme.of(context).colorScheme.onSurface)
                : null,
          ),
        ),
      ],
    );
  }
}
