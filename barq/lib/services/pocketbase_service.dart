import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tow_request_model.dart';
import '../models/user_model.dart';
import 'app_config.dart';

class PocketBaseService {
  PocketBaseService._internal(PocketBase client) : _client = client;

  static const String configuredUrl = AppConfig.pocketBaseUrl;
  static const int sessionDays = 15;
  static const String _loginTimestampKey = 'pb_login_timestamp';
  static const String _driverProfilesCollection = 'driver_profiles';

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
  String get currentUserName {
    final name = currentUserRecord?.getStringValue('name').trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }

    final email = currentUserRecord?.getStringValue('email').trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Driver';
  }

  String get currentUserRole {
    final record = currentUserRecord;
    if (record == null) {
      return 'customer';
    }
    return User.resolveRoleFromRecord(record);
  }

  bool get isCurrentUserDriver => currentUserRole == 'driver';

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

  Future<RecordModel?> refreshCurrentUserRecord() async {
    final userId = _userId;
    if (userId == null) {
      return null;
    }

    final record = await _client.collection('users').getOne(userId);
    _client.authStore.save(_client.authStore.token, record);
    return record;
  }

  Future<RecordModel> updateCurrentUserRole(String role) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final normalizedRole = User.normalizeRole(role);
    final isDriverRole = normalizedRole == 'driver';
    const roleFieldCandidates = <String>[
      'role',
      'account_type',
      'accountType',
      'user_type',
      'userType',
      'type',
    ];
    const booleanRoleFieldCandidates = <String>[
      'driver',
      'Driver',
      'is_driver',
      'isDriver',
    ];

    ClientException? lastException;
    for (final fieldName in roleFieldCandidates) {
      try {
        final updated = await _client.collection('users').update(
          userId,
          body: <String, dynamic>{fieldName: normalizedRole},
        );
        _client.authStore.save(_client.authStore.token, updated);
        return updated;
      } on ClientException catch (e) {
        lastException = e;
        if (_isMissingFieldError(e, fieldName)) {
          continue;
        }
        rethrow;
      }
    }

    for (final fieldName in booleanRoleFieldCandidates) {
      try {
        final updated = await _client.collection('users').update(
          userId,
          body: <String, dynamic>{fieldName: isDriverRole},
        );
        _client.authStore.save(_client.authStore.token, updated);
        return updated;
      } on ClientException catch (e) {
        lastException = e;
        if (_isMissingFieldError(e, fieldName)) {
          continue;
        }
        rethrow;
      }
    }

    if (lastException != null) {
      throw lastException;
    }

    throw Exception(
      'No role field exists in users collection. Add one of: role/account_type or driver/Driver.',
    );
  }

  Future<RecordModel?> getCurrentDriverProfile() async {
    final userId = _userId;
    if (userId == null) {
      return null;
    }

    try {
      final result =
          await _client.collection(_driverProfilesCollection).getList(
                page: 1,
                perPage: 1,
                filter: 'user = "$userId"',
                sort: '-updated',
              );
      if (result.items.isEmpty) {
        return null;
      }
      return result.items.first;
    } on ClientException catch (e) {
      if (_isMissingCollectionError(e)) {
        throw Exception(_driverProfilesSetupMessage);
      }
      rethrow;
    }
  }

  Future<RecordModel> upsertCurrentDriverProfile({
    required String driverName,
    String? licensePlate,
    double? driverRating,
    int? driverTotalRides,
    int? defaultEtaMinutes,
    double? defaultDistanceKm,
    double? driverLat,
    double? driverLng,
    bool? isAvailable,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final normalizedDriverName = driverName.trim();
    if (normalizedDriverName.isEmpty) {
      throw Exception('Driver name is required');
    }

    final existing = await getCurrentDriverProfile();
    final body = <String, dynamic>{
      'user': userId,
      'driver_name': normalizedDriverName,
      if (licensePlate != null && licensePlate.trim().isNotEmpty)
        'license_plate': licensePlate.trim(),
      if (driverRating != null) 'driver_rating': driverRating,
      if (driverTotalRides != null) 'driver_total_rides': driverTotalRides,
      if (defaultEtaMinutes != null) 'default_eta_minutes': defaultEtaMinutes,
      if (defaultDistanceKm != null) 'default_distance_km': defaultDistanceKm,
      if (driverLat != null) 'driver_lat': driverLat,
      if (driverLng != null) 'driver_lng': driverLng,
      if (isAvailable != null) 'is_available': isAvailable,
    };

    try {
      if (existing == null) {
        return await _client.collection(_driverProfilesCollection).create(
              body: body,
            );
      }
      return await _client.collection(_driverProfilesCollection).update(
            existing.id,
            body: body,
          );
    } on ClientException catch (e) {
      if (_isMissingCollectionError(e)) {
        throw Exception(_driverProfilesSetupMessage);
      }
      rethrow;
    }
  }

  Future<RecordModel> ensureCurrentDriverProfile() async {
    final existing = await getCurrentDriverProfile();
    if (existing != null) {
      return existing;
    }

    return upsertCurrentDriverProfile(
      driverName: currentUserName,
    );
  }

  Future<List<RecordModel>> getDriverProfiles({int limit = 200}) async {
    try {
      final result =
          await _client.collection(_driverProfilesCollection).getList(
                page: 1,
                perPage: limit,
                sort: '-updated',
              );
      return result.items;
    } on ClientException catch (e) {
      if (_isMissingCollectionError(e)) {
        return const <RecordModel>[];
      }
      rethrow;
    }
  }

  /// Request an OTP code. [identity] can be an email or a phone number.
  /// For phone numbers, PocketBase must have an SMS provider hook configured.
  Future<String> requestOtp(String identity) async {
    final result =
        await _client.collection('users').requestOTP(identity.trim());
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
          if (createBody.containsKey('phoneNumber') &&
              _isPhoneFieldRejected(e2)) {
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

  bool _isMissingFieldError(ClientException e, String fieldName) {
    final response = e.response;
    final message = (response['message'] as String?)?.toLowerCase() ?? '';
    if (message.contains('failed to find field') ||
        message.contains('unknown field') ||
        message.contains('field not found')) {
      return true;
    }

    final data = response['data'];
    if (data is! Map || !data.containsKey(fieldName)) {
      return false;
    }

    final fieldError = data[fieldName];
    if (fieldError is! Map) {
      return false;
    }

    final fieldMessage =
        (fieldError['message'] as String?)?.toLowerCase() ?? '';
    return fieldMessage.contains('failed to find field') ||
        fieldMessage.contains('unknown field') ||
        fieldMessage.contains('field not found');
  }

  bool _isMissingCollectionError(ClientException e) {
    final response = e.response;
    final message = (response['message'] as String?)?.toLowerCase() ?? '';
    return message.contains('missing or invalid collection') ||
        message.contains('missing collection') ||
        message.contains('failed to find collection') ||
        message.contains(_driverProfilesCollection);
  }

  String get _driverProfilesSetupMessage =>
      'Missing "$_driverProfilesCollection" collection. Create it with a relation field "user" -> users and text field "driver_name".';

  Future<TowRequest> createTowRequest({
    required String pickupLocation,
    required String destination,
    required String vehicleType,
    String details = '',
    required String serviceTiming,
    String status = 'pending',
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    double? driverLat,
    double? driverLng,
    String? driverName,
    double? driverRating,
    int? driverTotalRides,
    String? licensePlate,
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
      'status': status.trim().isEmpty ? 'pending' : status.trim(),
    };

    final enhancedPayload = <String, dynamic>{
      ...requiredPayload,
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
      if (destinationLat != null) 'destination_lat': destinationLat,
      if (destinationLng != null) 'destination_lng': destinationLng,
      if (driverLat != null) 'driver_lat': driverLat,
      if (driverLng != null) 'driver_lng': driverLng,
      if (driverName != null && driverName.trim().isNotEmpty)
        'driver_name': driverName.trim(),
      if (driverRating != null) 'driver_rating': driverRating,
      if (driverTotalRides != null) 'driver_total_rides': driverTotalRides,
      if (licensePlate != null && licensePlate.trim().isNotEmpty)
        'license_plate': licensePlate.trim(),
      if (distanceKm != null) 'distance_km': distanceKm,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
      if (baseFare != null) 'base_fare': baseFare,
      if (distanceFare != null) 'distance_fare': distanceFare,
    };

    RecordModel record;
    try {
      record = await _client
          .collection('tow_requests')
          .create(body: enhancedPayload);
    } on ClientException catch (e) {
      if (_hasRejectedOptionalField(
        e,
        const <String>[
          'pickup_lat',
          'pickup_lng',
          'destination_lat',
          'destination_lng',
          'driver_lat',
          'driver_lng',
          'driver_name',
          'driver_rating',
          'driver_total_rides',
          'license_plate',
          'distance_km',
          'eta_minutes',
          'base_fare',
          'distance_fare',
        ],
      )) {
        record = await _client
            .collection('tow_requests')
            .create(body: requiredPayload);
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

  Future<List<TowRequest>> getPendingTowRequests() async {
    if (!isCurrentUserDriver) {
      throw Exception('Driver role is required.');
    }

    final result = await _client.collection('tow_requests').getList(
          page: 1,
          perPage: 200,
          filter: 'status = "pending"',
          sort: 'created',
        );

    return result.items.map(TowRequest.fromRecord).toList(growable: false);
  }

  Future<List<TowRequest>> getDriverActiveRequests(String driverName) async {
    if (!isCurrentUserDriver) {
      throw Exception('Driver role is required.');
    }

    final normalizedDriver = driverName.trim();
    if (normalizedDriver.isEmpty) {
      return const <TowRequest>[];
    }

    final escapedDriver = _escapeFilterValue(normalizedDriver);
    final result = await _client.collection('tow_requests').getList(
          page: 1,
          perPage: 200,
          filter:
              'driver_name = "$escapedDriver" && (status = "assigned" || status = "en_route")',
          sort: '-updated',
        );

    return result.items.map(TowRequest.fromRecord).toList(growable: false);
  }

  Future<TowRequest> updateTowRequestAsDriver({
    required String requestId,
    String? status,
    String? driverName,
    String? licensePlate,
    double? driverRating,
    int? driverTotalRides,
    double? distanceKm,
    int? etaMinutes,
    double? baseFare,
    double? distanceFare,
  }) async {
    if (!isCurrentUserDriver) {
      throw Exception('Driver role is required.');
    }

    final body = <String, dynamic>{
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (driverName != null && driverName.trim().isNotEmpty)
        'driver_name': driverName.trim(),
      if (licensePlate != null && licensePlate.trim().isNotEmpty)
        'license_plate': licensePlate.trim(),
      if (driverRating != null) 'driver_rating': driverRating,
      if (driverTotalRides != null) 'driver_total_rides': driverTotalRides,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
      if (baseFare != null) 'base_fare': baseFare,
      if (distanceFare != null) 'distance_fare': distanceFare,
    };

    if (body.isEmpty) {
      final record = await _client.collection('tow_requests').getOne(requestId);
      return TowRequest.fromRecord(record);
    }

    final record = await _client.collection('tow_requests').update(
          requestId,
          body: body,
        );
    return TowRequest.fromRecord(record);
  }

  String _escapeFilterValue(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
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

    final requests =
        result.items.map(TowRequest.fromRecord).toList(growable: false);
    final totalSpent =
        requests.fold<double>(0, (sum, item) => sum + item.totalFare);

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
