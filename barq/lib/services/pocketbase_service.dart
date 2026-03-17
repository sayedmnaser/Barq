import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tow_request_model.dart';
import 'app_config.dart';

class PocketBaseService {
  PocketBaseService._internal(PocketBase client) : _client = client;

  static const String configuredUrl = AppConfig.pocketBaseUrl;
  static const int sessionDays = 15;
  static const String _loginTimestampKey = 'pb_login_timestamp';

  static PocketBaseService? _instance;

  static PocketBaseService get instance {
    if (_instance == null) {
      throw StateError(
        'PocketBaseService not initialized. Call PocketBaseService.init() first.',
      );
    }
    return _instance!;
  }

  /// Initializes the service with a persistent auth store.
  /// Must be called once before accessing [instance].
  static Future<void> init() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();
    final store = AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
    );
    final client = PocketBase(
      _normalizeBaseUrl(configuredUrl),
      authStore: store,
    );
    _instance = PocketBaseService._internal(client);
    await _instance!._enforceSessionExpiry(prefs);
  }

  final PocketBase _client;

  PocketBase get client => _client;

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String get serverUrl => _normalizeBaseUrl(configuredUrl);

  bool get isUsingDefaultLocalUrl => AppConfig.usesPocketBasePlaceholder;

  bool get isAuthenticated => _client.authStore.isValid;

  RecordModel? get currentUserRecord => _client.authStore.record;

  String? get _userId => currentUserRecord?.id;

  Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.collection('users').authWithPassword(email.trim(), password);
    await _stampLoginTime();
  }

  Future<void> signOut() async {
    _client.authStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginTimestampKey);
  }

  /// Request an OTP code. [identity] can be an email or a phone number.
  /// For phone numbers, PocketBase must have an SMS provider hook configured.
  Future<String> requestOtp(String identity) async {
    final result = await _client.collection('users').requestOTP(identity.trim());
    return result.otpId;
  }

  /// Authenticate using the OTP code returned to the user.
  Future<void> authWithOtp({
    required String otpId,
    required String code,
  }) async {
    await _client.collection('users').authWithOTP(otpId, code.trim());
    await _stampLoginTime();
  }

  /// Record the current time as the login timestamp.
  Future<void> _stampLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _loginTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Clear session if older than [sessionDays].
  Future<void> _enforceSessionExpiry(SharedPreferences prefs) async {
    if (!_client.authStore.isValid) return;
    final stamp = prefs.getInt(_loginTimestampKey);
    if (stamp == null) {
      // No timestamp recorded — treat as expired.
      _client.authStore.clear();
      return;
    }
    final loginDate = DateTime.fromMillisecondsSinceEpoch(stamp);
    if (DateTime.now().difference(loginDate).inDays >= sessionDays) {
      _client.authStore.clear();
      await prefs.remove(_loginTimestampKey);
    }
  }

  /// Convenience: resolve an identifier to the value PocketBase expects.
  /// If [value] looks like a phone number, convert to the username format
  /// stored during sign-up ("phone97336380308").
  /// Otherwise assume it is an email and return as-is.
  String resolveIdentity(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('@')) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) return 'phone973$digits';
    if (digits.length > 8) return 'phone$digits';
    return trimmed;
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    String? phone,
  }) async {
    final createBody = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'passwordConfirm': confirmPassword,
      'name': fullName.trim(),
    };

    // Store normalized phone as username so PocketBase can find the user
    // by phone number during OTP sign-in.
    final normalizedPhone = normalizePhone(phone ?? '');
    if (normalizedPhone != null) {
      createBody['phoneNumber'] = normalizedPhone;
      createBody['username'] = 'phone$normalizedPhone';
    }

    try {
      await _client.collection('users').create(body: createBody);
    } on ClientException catch (e) {
      if (createBody.containsKey('phoneNumber') && _isPhoneFieldRejected(e)) {
        createBody.remove('phoneNumber');
        createBody.remove('username');
        await _client.collection('users').create(body: createBody);
      } else if (createBody.containsKey('username') && _isUsernameRejected(e)) {
        createBody.remove('username');
        try {
          await _client.collection('users').create(body: createBody);
        } on ClientException catch (e2) {
          if (createBody.containsKey('phoneNumber') && _isPhoneFieldRejected(e2)) {
            createBody.remove('phoneNumber');
            await _client.collection('users').create(body: createBody);
          } else {
            rethrow;
          }
        }
      } else {
        rethrow;
      }
    }

    await signIn(email: email, password: password);
  }

  int? normalizePhone(String value) {
    final input = value.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (input.isEmpty) {
      return null;
    }

    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    if (input.startsWith('+') && RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(input)) {
      return int.tryParse(digitsOnly);
    }

    if (RegExp(r'^\d{8}$').hasMatch(digitsOnly)) {
      return int.tryParse('973$digitsOnly');
    }

    return null;
  }

  bool _isPhoneFieldRejected(ClientException e) {
    final response = e.response;
    final data = response['data'];
    if (data is Map && data.containsKey('phoneNumber')) {
      return true;
    }

    final message = (response['message'] as String?)?.toLowerCase() ?? '';
    return message.contains('phonenumber') || message.contains('phone');
  }

  bool _isUsernameRejected(ClientException e) {
    final response = e.response;
    final data = response['data'];
    if (data is Map && data.containsKey('username')) {
      return true;
    }
    final message = (response['message'] as String?)?.toLowerCase() ?? '';
    return message.contains('username');
  }

  Future<TowRequest> createTowRequest({
    required String pickupLocation,
    required String destination,
    required String vehicleType,
    String details = '',
    required String serviceTiming,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    double? distanceKm,
    int? etaMinutes,
    double? baseFare,
    double? distanceFare,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final requiredPayload = <String, dynamic>{
      'user': userId,
      'pickup_location': pickupLocation,
      'destination': destination,
      'vehicle_type': vehicleType,
      'details': details,
      'service_timing': serviceTiming,
      'status': 'pending',
    };

    final enhancedPayload = <String, dynamic>{
      ...requiredPayload,
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
      if (destinationLat != null) 'destination_lat': destinationLat,
      if (destinationLng != null) 'destination_lng': destinationLng,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
      if (baseFare != null) 'base_fare': baseFare,
      if (distanceFare != null) 'distance_fare': distanceFare,
    };

    RecordModel record;
    try {
      record = await _client.collection('tow_requests').create(body: enhancedPayload);
    } on ClientException catch (e) {
      if (_hasRejectedOptionalField(
        e,
        const <String>[
          'pickup_lat',
          'pickup_lng',
          'destination_lat',
          'destination_lng',
          'distance_km',
          'eta_minutes',
          'base_fare',
          'distance_fare',
        ],
      )) {
        record = await _client.collection('tow_requests').create(body: requiredPayload);
      } else {
        rethrow;
      }
    }

    return TowRequest.fromRecord(record);
  }

  bool _hasRejectedOptionalField(ClientException e, List<String> fieldNames) {
    final response = e.response;
    final data = response['data'];
    if (data is Map) {
      for (final field in fieldNames) {
        if (data.containsKey(field)) {
          return true;
        }
      }
    }

    final message = (response['message'] as String?)?.toLowerCase() ?? '';
    return fieldNames.any((field) => message.contains(field.toLowerCase()));
  }

  Future<List<TowRequest>> getActiveRequests() async {
    final userId = _userId;
    if (userId == null) {
      return const <TowRequest>[];
    }

    final result = await _client.collection('tow_requests').getList(
      page: 1,
      perPage: 200,
      filter:
          'user = "$userId" && (status = "pending" || status = "assigned" || status = "en_route")',
      sort: '-created',
    );

    return result.items.map(TowRequest.fromRecord).toList(growable: false);
  }

  Future<List<TowRequest>> getServiceHistory() async {
    final userId = _userId;
    if (userId == null) {
      return const <TowRequest>[];
    }

    final result = await _client.collection('tow_requests').getList(
      page: 1,
      perPage: 200,
      filter:
          'user = "$userId" && (status = "completed" || status = "cancelled")',
      sort: '-created',
    );

    return result.items.map(TowRequest.fromRecord).toList(growable: false);
  }

  Future<TowRequest> getTowRequest(String id) async {
    final record = await _client.collection('tow_requests').getOne(id);
    return TowRequest.fromRecord(record);
  }

  Future<void> cancelTowRequest(String id) async {
    await _client.collection('tow_requests').update(id, body: {
      'status': 'cancelled',
    });
  }

  Future<({int totalRides, double totalSpent})> getUserStats() async {
    final userId = _userId;
    if (userId == null) {
      return (totalRides: 0, totalSpent: 0.0);
    }

    final result = await _client.collection('tow_requests').getList(
      page: 1,
      perPage: 200,
      filter: 'user = "$userId" && status = "completed"',
      sort: '-created',
    );

    final requests = result.items.map(TowRequest.fromRecord).toList(growable: false);
    final totalSpent = requests.fold<double>(0, (sum, item) => sum + item.totalFare);

    return (totalRides: requests.length, totalSpent: totalSpent);
  }

  Future<void> subscribeTowRequest(
    String requestId,
    void Function(TowRequest updated) onUpdate,
  ) async {
    await _client.collection('tow_requests').subscribe(requestId, (event) {
      final record = event.record;
      if (record != null) {
        onUpdate(TowRequest.fromRecord(record));
      }
    });
  }

  Future<void> subscribeCurrentUserRequests(void Function() onChange) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    await _client.collection('tow_requests').subscribe('*', (event) {
      final record = event.record;
      if (record != null && record.getStringValue('user') == userId) {
        onChange();
      }
    });
  }

  Future<void> unsubscribeTowRequest(String requestId) async {
    _client.collection('tow_requests').unsubscribe(requestId);
  }

  Future<void> unsubscribeAll() async {
    _client.collection('tow_requests').unsubscribe();
  }

  Future<void> unsubscribeCurrentUserRequests() async {
    _client.collection('tow_requests').unsubscribe('*');
  }

  Future<bool> canReachServerNow() async {
    try {
      return await ping();
    } on SocketException {
      return false;
    }
  }
}
