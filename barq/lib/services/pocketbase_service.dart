import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../models/tow_request_model.dart';
import 'app_config.dart';

class PocketBaseService {
  PocketBaseService._internal()
      : _client = PocketBase(_normalizeBaseUrl(configuredUrl));

  static const String configuredUrl = AppConfig.pocketBaseUrl;

  static final PocketBaseService instance = PocketBaseService._internal();

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
  }

  Future<void> signOut() async {
    _client.authStore.clear();
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

    final normalizedPhone = normalizePhone(phone ?? '');
    if (normalizedPhone != null) {
      createBody['phoneNumber'] = normalizedPhone;
    }

    try {
      await _client.collection('users').create(body: createBody);
    } on ClientException catch (e) {
      if (createBody.containsKey('phoneNumber') && _isPhoneFieldRejected(e)) {
        createBody.remove('phoneNumber');
        await _client.collection('users').create(body: createBody);
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
