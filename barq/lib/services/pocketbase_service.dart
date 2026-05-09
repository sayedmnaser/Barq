import 'dart:io';
import 'dart:math' as math;

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
  static const double _autoCompleteRadiusMeters = 150.0;
  static const Duration pendingRequestTtl = Duration(minutes: 15);

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

  bool get isCurrentUserDriverToggleEnabled {
    final record = currentUserRecord;
    if (record == null) {
      return false;
    }

    const booleanDriverCandidates = <String>[
      'driver',
      'Driver',
      'is_driver',
      'isDriver',
    ];

    for (final field in booleanDriverCandidates) {
      if (record.getBoolValue(field)) {
        return true;
      }
    }

    return false;
  }

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
    String? driverPhone,
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
      if (driverPhone != null && driverPhone.trim().isNotEmpty)
        'driver_phone': driverPhone.trim(),
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
    String? driverUserId,
    List<String> candidateDriverIds = const <String>[],
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
      if (driverUserId != null && driverUserId.trim().isNotEmpty)
        'driver': driverUserId.trim(),
      if (candidateDriverIds.isNotEmpty)
        'candidate_drivers': candidateDriverIds,
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
          'driver',
          'candidate_drivers',
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
    // No message-substring fallback: it caused false positives where an error
    // about a sibling field (e.g. driver_rating) would match the shorter name
    // (e.g. driver) and strip a valid field from the retry payload.
    return false;
  }

  Future<List<TowRequest>> getActiveRequests() async {
    final userId = _userId;
    if (userId == null) {
      return const <TowRequest>[];
    }

    await cleanupExpiredPendingRequests();

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
          filter: 'user = "$userId" && status = "completed"',
          sort: '-created',
        );

    return result.items.map(TowRequest.fromRecord).toList(growable: false);
  }

  Future<List<TowRequest>> getPendingTowRequests() async {
    if (!isCurrentUserDriver) {
      throw Exception('Driver role is required.');
    }

    await cleanupExpiredPendingRequests(includeDriverVisible: true);

    final selfId = _userId ?? '';
    final selfFilter =
        selfId.isEmpty ? '' : ' && user != "${_escapeFilterValue(selfId)}"';
    final result = await _client.collection('tow_requests').getList(
          page: 1,
          perPage: 200,
          filter: 'status = "pending"$selfFilter',
          sort: 'created',
        );

    final requests =
        result.items.map(TowRequest.fromRecord).toList(growable: false);
    if (selfId.isEmpty) {
      return requests;
    }

    return requests.where((request) {
      if (request.candidateDriverIds.isEmpty) {
        return true;
      }
      return request.candidateDriverIds.contains(selfId);
    }).toList(growable: false);
  }

  Future<List<TowRequest>> getDriverActiveRequests(String driverName) async {
    if (!isCurrentUserDriver) {
      throw Exception('Driver role is required.');
    }

    final userId = _userId?.trim() ?? '';
    final normalizedDriver = driverName.trim();
    if (userId.isEmpty && normalizedDriver.isEmpty) {
      return const <TowRequest>[];
    }

    final driverFilter = userId.isNotEmpty
        ? 'driver = "${_escapeFilterValue(userId)}"'
        : 'driver_name = "${_escapeFilterValue(normalizedDriver)}"';
    final result = await _client.collection('tow_requests').getList(
          page: 1,
          perPage: 200,
          filter:
              '$driverFilter && (status = "assigned" || status = "en_route")',
          sort: '-updated',
        );

    return result.items.map(TowRequest.fromRecord).toList(growable: false);
  }

  Future<List<TowRequest>> getDriverServiceHistory(String driverName) async {
    if (!isCurrentUserDriver) {
      throw Exception('Driver role is required.');
    }

    final normalizedDriver = driverName.trim();
    final userId = _userId?.trim() ?? '';
    if (userId.isEmpty && normalizedDriver.isEmpty) {
      return const <TowRequest>[];
    }

    final driverFilter = userId.isNotEmpty
        ? 'driver = "${_escapeFilterValue(userId)}"'
        : 'driver_name = "${_escapeFilterValue(normalizedDriver)}"';

    final result = await _client.collection('tow_requests').getList(
          page: 1,
          perPage: 200,
          filter: '$driverFilter && status = "completed"',
          sort: '-updated',
        );

    return result.items.map(TowRequest.fromRecord).toList(growable: false);
  }

  Future<void> cleanupExpiredPendingRequests({
    bool includeDriverVisible = false,
  }) async {
    final userId = _userId?.trim();
    if (userId == null || userId.isEmpty) {
      return;
    }

    final cutoff =
        DateTime.now().toUtc().subtract(pendingRequestTtl).toIso8601String();
    final filters = <String>[
      'status = "pending"',
      'created <= "$cutoff"',
    ];
    if (!includeDriverVisible || !isCurrentUserDriver) {
      filters.add('user = "${_escapeFilterValue(userId)}"');
    }

    List<RecordModel> expired;
    try {
      final result = await _client.collection('tow_requests').getList(
            page: 1,
            perPage: 200,
            filter: filters.join(' && '),
            sort: 'created',
          );
      expired = result.items;
    } on ClientException {
      return;
    }

    for (final record in expired) {
      final ownerId = record.getStringValue('user').trim();
      final ownsRequest = ownerId == userId;
      if (ownsRequest) {
        try {
          await _client.collection('tow_requests').delete(record.id);
          continue;
        } on ClientException {
          // Fall through to status update when delete rules are stricter.
        }
      }

      try {
        await _client.collection('tow_requests').update(
          record.id,
          body: const <String, dynamic>{'status': 'expired'},
        );
      } on ClientException {
        // Best effort cleanup; hidden filters still keep successful rows out.
      }
    }
  }

  /// Pushes the driver's live coordinates to every active tow_request currently
  /// assigned to the signed-in driver. The user-facing Track Service screen
  /// reads driver_lat/driver_lng from the tow_request, so this is what makes
  /// the live driver marker appear on the customer map.
  ///
  /// Also self-heals the `driver` relation on rows that were accepted before
  /// the relation could be persisted, by matching on `driver_name`.
  Future<bool> pushDriverLocationToActiveRequests({
    required double latitude,
    required double longitude,
    String? driverName,
  }) async {
    if (!isCurrentUserDriver) {
      return false;
    }
    final userId = _userId;
    if (userId == null) {
      return false;
    }

    final escapedUserId = _escapeFilterValue(userId);
    final filters = <String>['driver = "$escapedUserId"'];
    final normalizedDriverName = (driverName ?? currentUserName).trim();
    if (normalizedDriverName.isNotEmpty) {
      filters
          .add('driver_name = "${_escapeFilterValue(normalizedDriverName)}"');
    }
    final driverFilter =
        filters.length == 1 ? filters.first : '(${filters.join(' || ')})';

    List<RecordModel> records = const <RecordModel>[];
    try {
      final result = await _client.collection('tow_requests').getList(
            page: 1,
            perPage: 200,
            filter:
                '$driverFilter && (status = "assigned" || status = "en_route")',
            sort: '-updated',
          );
      records = result.items;
    } on ClientException {
      records = const <RecordModel>[];
    }

    if (records.isEmpty) {
      return false;
    }

    var completedAny = false;
    for (final record in records) {
      final body = <String, dynamic>{
        'driver_lat': latitude,
        'driver_lng': longitude,
      };
      final status = record.getStringValue('status');
      final destinationLat = _recordCoordinate(record, 'destination_lat');
      final destinationLng = _recordCoordinate(record, 'destination_lng');
      if (status == 'en_route' &&
          destinationLat != null &&
          destinationLng != null) {
        final meters = _haversineMeters(
          latitude,
          longitude,
          destinationLat,
          destinationLng,
        );
        if (meters <= _autoCompleteRadiusMeters) {
          body['status'] = 'completed';
          body['eta_minutes'] = 0;
        }
      }
      // Heal missing relation so the customer-side filter & rules light up.
      if (record.getStringValue('driver').trim().isEmpty) {
        body['driver'] = userId;
      }
      try {
        await _client.collection('tow_requests').update(record.id, body: body);
        if (body['status'] == 'completed') {
          completedAny = true;
        }
      } on ClientException {
        // Skip rows that reject the update; other rows can still succeed.
      }
    }
    return completedAny;
  }

  double? _recordCoordinate(RecordModel record, String field) {
    final value = record.getDoubleValue(field);
    return value == 0 ? null : value;
  }

  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.sqrt(a));
  }

  Future<TowRequest> updateTowRequestAsDriver({
    required String requestId,
    String? status,
    String? driverName,
    String? licensePlate,
    String? driverPhone,
    double? driverRating,
    int? driverTotalRides,
    double? distanceKm,
    int? etaMinutes,
    double? baseFare,
    double? distanceFare,
    bool attachDriverUser = true,
  }) async {
    if (!isCurrentUserDriver) {
      throw Exception('Driver role is required.');
    }
    if (status?.trim() == 'completed') {
      throw Exception(
        'Trips complete automatically when the driver reaches the destination.',
      );
    }

    final requestedStatus = status?.trim();
    if (attachDriverUser && _userId != null) {
      RecordModel? existing;
      try {
        existing = await _client.collection('tow_requests').getOne(requestId);
      } on ClientException {
        existing = null;
      }

      if (existing != null) {
        if (existing.getStringValue('user') == _userId) {
          throw Exception('You cannot accept your own tow request.');
        }
        final existingDriver = existing.getStringValue('driver').trim();
        if (existingDriver.isNotEmpty && existingDriver != _userId) {
          throw Exception('Another driver already accepted this request.');
        }
        final candidates = existing.getListValue<String>('candidate_drivers');
        if ((requestedStatus == 'assigned' || requestedStatus == 'en_route') &&
            candidates.isNotEmpty &&
            !candidates.contains(_userId)) {
          throw Exception('This request is reserved for the closest drivers.');
        }
        final existingStatus = existing.getStringValue('status').trim();
        if (requestedStatus == 'assigned' && existingStatus != 'pending') {
          throw Exception('Another driver already accepted this request.');
        }
      }
    }

    final body = <String, dynamic>{
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (driverName != null && driverName.trim().isNotEmpty)
        'driver_name': driverName.trim(),
      if (licensePlate != null && licensePlate.trim().isNotEmpty)
        'license_plate': licensePlate.trim(),
      if (driverPhone != null && driverPhone.trim().isNotEmpty)
        'driver_phone': driverPhone.trim(),
      if (driverRating != null) 'driver_rating': driverRating,
      if (driverTotalRides != null) 'driver_total_rides': driverTotalRides,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
      if (baseFare != null) 'base_fare': baseFare,
      if (distanceFare != null) 'distance_fare': distanceFare,
      if (attachDriverUser && _userId != null) 'driver': _userId,
    };

    if (body.isEmpty) {
      final record = await _client.collection('tow_requests').getOne(requestId);
      return TowRequest.fromRecord(record);
    }

    RecordModel record;
    try {
      record = await _client.collection('tow_requests').update(
            requestId,
            body: body,
          );
    } on ClientException catch (e) {
      if (body.containsKey('driver') &&
          _hasRejectedOptionalField(e, const ['driver'])) {
        body.remove('driver');
        record = await _client.collection('tow_requests').update(
              requestId,
              body: body,
            );
      } else {
        rethrow;
      }
    }
    return TowRequest.fromRecord(record);
  }

  Future<void> updateTowRequestCoordinates({
    required String requestId,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
  }) async {
    final body = <String, dynamic>{
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
      if (destinationLat != null) 'destination_lat': destinationLat,
      if (destinationLng != null) 'destination_lng': destinationLng,
    };
    if (body.isEmpty) {
      return;
    }
    await _client.collection('tow_requests').update(requestId, body: body);
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

  /// Driver requests to cancel an accepted job. Sets status to cancel_pending
  /// and records the reason. The decision is finalised by AI in
  /// [applyDriverCancellationVerdict].
  Future<TowRequest> requestDriverCancellation({
    required String requestId,
    required String reason,
  }) async {
    if (!isCurrentUserDriver) {
      throw Exception('Driver role is required.');
    }
    final trimmed = reason.trim();
    if (trimmed.length < 5) {
      throw ArgumentError('Cancellation reason is too short.');
    }
    final body = <String, dynamic>{
      'status': 'cancel_pending',
      'cancellation_reason': trimmed,
    };
    RecordModel record;
    try {
      record = await _client.collection('tow_requests').update(
            requestId,
            body: body,
          );
    } on ClientException catch (e) {
      if (_hasRejectedOptionalField(e, const ['cancellation_reason'])) {
        body.remove('cancellation_reason');
        record = await _client.collection('tow_requests').update(
              requestId,
              body: body,
            );
      } else {
        rethrow;
      }
    }
    return TowRequest.fromRecord(record);
  }

  Future<TowRequest> applyDriverCancellationVerdict({
    required String requestId,
    required String decision,
    required String reasoning,
    required double confidence,
    required String previousStatus,
  }) async {
    final normalisedPrev =
        previousStatus.isNotEmpty ? previousStatus : 'en_route';
    final body = <String, dynamic>{
      'cancellation_verdict': reasoning,
      'cancellation_decision': decision,
      'cancellation_ai_confidence': confidence,
      'status': switch (decision) {
        'approved' => 'cancelled',
        'rejected' => normalisedPrev,
        _ => 'cancel_pending',
      },
    };

    RecordModel record;
    try {
      record = await _client
          .collection('tow_requests')
          .update(requestId, body: body);
    } on ClientException catch (e) {
      if (_hasRejectedOptionalField(e, const [
        'cancellation_verdict',
        'cancellation_decision',
        'cancellation_ai_confidence',
      ])) {
        body.removeWhere((k, _) => k.startsWith('cancellation_'));
        record = await _client
            .collection('tow_requests')
            .update(requestId, body: body);
      } else {
        rethrow;
      }
    }
    return TowRequest.fromRecord(record);
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
      if (record == null || record.getStringValue('user') == userId) {
        onChange();
      }
    });
  }

  Future<void> subscribeDriverTowRequests(void Function() onChange) async {
    if (!isCurrentUserDriver) {
      return;
    }

    await _client.collection('tow_requests').subscribe('*', (_) {
      onChange();
    });
  }

  Future<void> subscribeDriverProfiles(void Function() onChange) async {
    await _client.collection(_driverProfilesCollection).subscribe('*', (_) {
      onChange();
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

  Future<void> unsubscribeDriverTowRequests() async {
    _client.collection('tow_requests').unsubscribe('*');
  }

  Future<void> unsubscribeDriverProfiles() async {
    _client.collection(_driverProfilesCollection).unsubscribe('*');
  }

  Future<bool> canReachServerNow() async {
    try {
      return await ping();
    } on SocketException {
      return false;
    }
  }

  // ---------------- photos on tow_requests ----------------

  Future<TowRequest> uploadTowRequestPhoto({
    required String requestId,
    required String fieldName,
    required String filePath,
  }) async {
    if (!const {'pickup_photo', 'dropoff_photo', 'damage_photos'}
        .contains(fieldName)) {
      throw ArgumentError('Invalid photo field: $fieldName');
    }

    final file = await http.MultipartFile.fromPath(fieldName, filePath);
    final record = await _client.collection('tow_requests').update(
      requestId,
      files: <http.MultipartFile>[file],
    );
    return TowRequest.fromRecord(record);
  }

  String fileUrl(RecordModel record, String fileName) {
    return _client.files.getUrl(record, fileName).toString();
  }

  String towRequestFileUrl(String recordId, String fileName) {
    if (recordId.isEmpty || fileName.isEmpty) return '';
    return '$serverUrl/api/files/tow_requests/$recordId/$fileName';
  }

  // ---------------- ratings ----------------

  Future<RecordModel> createRating({
    required String towRequestId,
    required String driverUserId,
    required int stars,
    String? comment,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');
    if (stars < 1 || stars > 5) throw ArgumentError('stars 1..5');

    final body = <String, dynamic>{
      'user': userId,
      'driver': driverUserId,
      'tow_request': towRequestId,
      'stars': stars,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    };
    final rating = await _client.collection('ratings').create(body: body);
    await _client.collection('tow_requests').update(
      towRequestId,
      body: <String, dynamic>{'rated': true},
    );
    return rating;
  }

  Future<RecordModel?> getRatingForRequest(String towRequestId) async {
    try {
      final result = await _client.collection('ratings').getList(
            page: 1,
            perPage: 1,
            filter: 'tow_request = "$towRequestId"',
          );
      return result.items.isEmpty ? null : result.items.first;
    } on ClientException {
      return null;
    }
  }

  /// Resolves a driver's user-id by their stored display name. Falls back
  /// across driver_profiles (preferred) then completed tow_requests so that
  /// rows missing the `driver` relation can still be rated.
  Future<String?> resolveDriverUserIdByName(String driverName) async {
    final clean = driverName.trim();
    if (clean.isEmpty) return null;
    final escaped = _escapeFilterValue(clean);

    try {
      final result =
          await _client.collection(_driverProfilesCollection).getList(
                page: 1,
                perPage: 1,
                filter: 'driver_name = "$escaped"',
                sort: '-updated',
              );
      if (result.items.isNotEmpty) {
        final userId = result.items.first.getStringValue('user').trim();
        if (userId.isNotEmpty) return userId;
      }
    } on ClientException {
      // ignore and fall through to tow_requests lookup
    }

    try {
      final result = await _client.collection('tow_requests').getList(
            page: 1,
            perPage: 1,
            filter: 'driver_name = "$escaped" && driver != ""',
            sort: '-updated',
          );
      if (result.items.isNotEmpty) {
        final userId = result.items.first.getStringValue('driver').trim();
        if (userId.isNotEmpty) return userId;
      }
    } on ClientException {
      // ignore
    }

    return null;
  }

  /// Tries to fetch a callable phone number for a driver. Looks up the
  /// driver_profiles row first, then falls back to the user record's
  /// phoneNumber field (which sign-up stores in international form).
  Future<String?> resolveDriverPhone({
    String? driverUserId,
    String? driverName,
  }) async {
    final cleanName = driverName?.trim() ?? '';
    final cleanId = driverUserId?.trim() ?? '';
    final filters = <String>[];
    if (cleanId.isNotEmpty) {
      filters.add('user = "${_escapeFilterValue(cleanId)}"');
    }
    if (cleanName.isNotEmpty) {
      filters.add('driver_name = "${_escapeFilterValue(cleanName)}"');
    }

    if (filters.isNotEmpty) {
      final filter =
          filters.length == 1 ? filters.first : '(${filters.join(' || ')})';
      try {
        final result =
            await _client.collection(_driverProfilesCollection).getList(
                  page: 1,
                  perPage: 1,
                  filter: filter,
                  sort: '-updated',
                );
        if (result.items.isNotEmpty) {
          final phone =
              result.items.first.getStringValue('driver_phone').trim();
          if (phone.isNotEmpty) return phone;
          final userId = result.items.first.getStringValue('user').trim();
          if (userId.isNotEmpty) {
            final fallback = await _phoneFromUserRecord(userId);
            if (fallback != null) return fallback;
          }
        }
      } on ClientException {
        // ignore and try direct user lookup
      }
    }

    if (cleanId.isNotEmpty) {
      final fallback = await _phoneFromUserRecord(cleanId);
      if (fallback != null) return fallback;
    }
    return null;
  }

  Future<String?> _phoneFromUserRecord(String userId) async {
    try {
      final user = await _client.collection('users').getOne(userId);
      final phone = user.getIntValue('phoneNumber');
      if (phone > 0) return '+$phone';
    } on ClientException {
      // user may not be readable due to rules
    }
    return null;
  }

  Future<List<RecordModel>> getRatingsForDriver(
    String driverUserId, {
    int limit = 50,
  }) async {
    try {
      final result = await _client.collection('ratings').getList(
            page: 1,
            perPage: limit,
            filter: 'driver = "$driverUserId"',
            sort: '-created',
          );
      return result.items;
    } on ClientException {
      return const <RecordModel>[];
    }
  }

  Future<double> getDriverAverageRating(String driverUserId) async {
    final result = await _client.collection('ratings').getList(
          page: 1,
          perPage: 500,
          filter: 'driver = "$driverUserId"',
        );
    if (result.items.isEmpty) return 0;
    final sum = result.items.fold<int>(
      0,
      (acc, r) => acc + r.getIntValue('stars'),
    );
    return sum / result.items.length;
  }

  // ---------------- driver reports ----------------

  Future<RecordModel> createDriverReport({
    String? driverUserId,
    String? towRequestId,
    required String category,
    required String description,
    List<String> photoPaths = const <String>[],
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');

    const allowed = {'rude', 'unsafe', 'no_show', 'damage', 'fraud', 'other'};
    if (!allowed.contains(category)) {
      throw ArgumentError('Invalid category: $category');
    }

    final body = <String, dynamic>{
      'reporter': userId,
      if (driverUserId != null && driverUserId.trim().isNotEmpty)
        'driver': driverUserId.trim(),
      if (towRequestId != null) 'tow_request': towRequestId,
      'category': category,
      'description': description,
      'status': 'pending_review',
    };

    final files = <http.MultipartFile>[];
    for (final p in photoPaths) {
      files.add(await http.MultipartFile.fromPath('photos', p));
    }

    return _client.collection('driver_reports').create(
          body: body,
          files: files,
        );
  }

  Future<RecordModel> applyAiReportVerdict({
    required String reportId,
    required String aiVerdict,
    required String aiAction,
    required double aiConfidence,
    String? newStatus,
  }) async {
    return _client.collection('driver_reports').update(
      reportId,
      body: <String, dynamic>{
        'ai_verdict': aiVerdict,
        'ai_action': aiAction,
        'ai_confidence': aiConfidence,
        'status': newStatus ?? 'ai_reviewed',
      },
    );
  }

  Future<List<RecordModel>> getMyDriverReports() async {
    final userId = _userId;
    if (userId == null) return const <RecordModel>[];
    final result = await _client.collection('driver_reports').getList(
          page: 1,
          perPage: 200,
          filter: 'reporter = "$userId"',
          sort: '-created',
        );
    return result.items;
  }

  // ---------------- driver applications ----------------

  Future<RecordModel?> getMyDriverApplication() async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final result = await _client.collection('driver_applications').getList(
            page: 1,
            perPage: 1,
            filter: 'user = "$userId"',
            sort: '-updated',
          );
      return result.items.isEmpty ? null : result.items.first;
    } on ClientException {
      return null;
    }
  }

  Future<RecordModel> submitDriverApplication({
    required String fullName,
    required String plateNumber,
    required String licenseFrontPath,
    required String licenseBackPath,
    required String nationalIdPath,
    required String carPhotoPath,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');

    final body = <String, dynamic>{
      'user': userId,
      'full_name': fullName.trim(),
      'plate_number': plateNumber.trim(),
      'status': 'submitted',
    };

    final files = <http.MultipartFile>[
      await http.MultipartFile.fromPath('license_front', licenseFrontPath),
      await http.MultipartFile.fromPath('license_back', licenseBackPath),
      await http.MultipartFile.fromPath('national_id', nationalIdPath),
      await http.MultipartFile.fromPath('car_photo', carPhotoPath),
    ];

    final existing = await getMyDriverApplication();
    final RecordModel record;
    if (existing == null) {
      record = await _client.collection('driver_applications').create(
            body: body,
            files: files,
          );
    } else {
      record = await _client.collection('driver_applications').update(
            existing.id,
            body: body,
            files: files,
          );
    }

    try {
      await _client.collection('users').update(
        userId,
        body: <String, dynamic>{'application_status': 'pending'},
      );
    } on ClientException {
      // non-fatal: field may be missing on older instances
    }

    return record;
  }

  Future<RecordModel> applyAiApplicationVerdict({
    required String applicationId,
    required String aiVerdict,
    required String aiDecision,
    required double aiConfidence,
  }) async {
    final newStatus = switch (aiDecision) {
      'approved' => 'approved',
      'rejected' => 'rejected',
      _ => 'ai_reviewed',
    };

    final record = await _client.collection('driver_applications').update(
      applicationId,
      body: <String, dynamic>{
        'ai_verdict': aiVerdict,
        'ai_decision': aiDecision,
        'ai_confidence': aiConfidence,
        'status': newStatus,
      },
    );

    final userField = record.getStringValue('user');
    if (userField.isNotEmpty &&
        (newStatus == 'approved' || newStatus == 'rejected')) {
      try {
        await _client.collection('users').update(
          userField,
          body: <String, dynamic>{'application_status': newStatus},
        );
      } on ClientException {
        // non-fatal
      }
    }

    return record;
  }

  // ---------------- support QA learning ----------------

  Future<RecordModel?> saveSupportQa({
    required String question,
    required String answer,
    required String language,
    String? tags,
  }) async {
    final body = <String, dynamic>{
      'question': question.trim(),
      'answer': answer.trim(),
      'language': language,
      if (tags != null && tags.trim().isNotEmpty) 'tags': tags.trim(),
      'helpful': 0,
      if (_userId != null) 'user': _userId,
    };
    try {
      return await _client.collection('support_qa').create(body: body);
    } on ClientException {
      return null;
    }
  }

  Future<void> markSupportQaHelpful({
    required String id,
    required int vote,
  }) async {
    final clamped = vote.clamp(-1, 1);
    try {
      await _client
          .collection('support_qa')
          .update(id, body: <String, dynamic>{'helpful': clamped});
    } on ClientException {
      // best-effort: write rules may forbid updates by other users
    }
  }

  Future<List<RecordModel>> getHelpfulSupportExamples({
    required String language,
    List<String> keywords = const <String>[],
    int limit = 3,
  }) async {
    final filters = <String>['helpful >= 1'];
    final lang = language.trim();
    if (lang.isNotEmpty) {
      filters.add('language = "${_escapeFilterValue(lang)}"');
    }
    if (keywords.isNotEmpty) {
      final kwClauses = keywords
          .map((k) => k.trim())
          .where((k) => k.length >= 3)
          .take(4)
          .map((k) {
        final esc = _escapeFilterValue(k);
        return '(question ~ "$esc" || tags ~ "$esc")';
      }).toList();
      if (kwClauses.isNotEmpty) {
        filters.add('(${kwClauses.join(' || ')})');
      }
    }
    try {
      final result = await _client.collection('support_qa').getList(
            page: 1,
            perPage: limit,
            filter: filters.join(' && '),
            sort: '-updated',
          );
      return result.items;
    } on ClientException {
      return const <RecordModel>[];
    }
  }

  Future<RecordModel> getRecord(String collection, String id) async {
    return _client.collection(collection).getOne(id);
  }
}
