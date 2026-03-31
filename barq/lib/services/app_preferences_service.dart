import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/place_result.dart';
import '../models/payment_method_model.dart';

class AppPreferenceSnapshot {
  const AppPreferenceSnapshot({
    required this.emailNotifications,
    required this.smsNotifications,
    required this.serviceUpdates,
    required this.shareLocation,
    required this.showProfile,
  });

  final bool emailNotifications;
  final bool smsNotifications;
  final bool serviceUpdates;
  final bool shareLocation;
  final bool showProfile;
}

class AppPreferencesService {
  AppPreferencesService._();

  static const String _emailNotificationsKey = 'prefs_email_notifications';
  static const String _smsNotificationsKey = 'prefs_sms_notifications';
  static const String _serviceUpdatesKey = 'prefs_service_updates';
  static const String _shareLocationKey = 'prefs_share_location';
  static const String _showProfileKey = 'prefs_show_profile';
  static const String _paymentMethodsKey = 'prefs_payment_methods_json';
  static const String _defaultPaymentMethodIdKey = 'prefs_default_payment_id';
  static const String _lastPickupPlaceKey = 'prefs_last_pickup_place_json';
  static const String _autoLocationPromptedKey = 'prefs_auto_location_prompted';

  static Future<AppPreferenceSnapshot> getPreferenceSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferenceSnapshot(
      emailNotifications: prefs.getBool(_emailNotificationsKey) ?? true,
      smsNotifications: prefs.getBool(_smsNotificationsKey) ?? false,
      serviceUpdates: prefs.getBool(_serviceUpdatesKey) ?? true,
      shareLocation: prefs.getBool(_shareLocationKey) ?? true,
      showProfile: prefs.getBool(_showProfileKey) ?? true,
    );
  }

  static Future<bool> getShareLocationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shareLocationKey) ?? true;
  }

  static Future<void> setEmailNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailNotificationsKey, enabled);
  }

  static Future<void> setSmsNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_smsNotificationsKey, enabled);
  }

  static Future<void> setServiceUpdatesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceUpdatesKey, enabled);
  }

  static Future<void> setShareLocationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shareLocationKey, enabled);
  }

  static Future<void> setShowProfileEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showProfileKey, enabled);
  }

  static Future<PlaceResult?> getLastPickupPlace() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_lastPickupPlaceKey) ?? '';
    if (encoded.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final title = (decoded['title'] as String?)?.trim() ?? '';
      final subtitle = (decoded['subtitle'] as String?)?.trim() ?? '';
      final latitude = (decoded['latitude'] as num?)?.toDouble();
      final longitude = (decoded['longitude'] as num?)?.toDouble();
      if (title.isEmpty || latitude == null || longitude == null) {
        return null;
      }
      return PlaceResult(
        title: title,
        subtitle: subtitle,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastPickupPlace(PlaceResult place) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastPickupPlaceKey,
      jsonEncode(<String, dynamic>{
        'title': place.title,
        'subtitle': place.subtitle,
        'latitude': place.latitude,
        'longitude': place.longitude,
      }),
    );
  }

  static Future<bool> getAutoLocationPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoLocationPromptedKey) ?? false;
  }

  static Future<void> setAutoLocationPrompted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLocationPromptedKey, value);
  }

  static Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_paymentMethodsKey) ?? '';
    final defaultId = prefs.getString(_defaultPaymentMethodIdKey);

    if (encoded.trim().isEmpty) {
      return <PaymentMethodModel>[
        const PaymentMethodModel(
          id: 'seed_card_4242',
          label: 'Visa',
          last4: '4242',
          expiry: '12/26',
          isDefault: true,
        ),
      ];
    }

    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final parsed = decoded
          .whereType<Map<String, dynamic>>()
          .map(PaymentMethodModel.fromJson)
          .where((method) =>
              method.id.isNotEmpty &&
              method.last4.length == 4 &&
              method.expiry.isNotEmpty)
          .toList(growable: false);

      if (parsed.isEmpty) {
        return const <PaymentMethodModel>[];
      }

      final resolvedDefaultId =
          (defaultId != null && parsed.any((method) => method.id == defaultId))
              ? defaultId
              : parsed.first.id;

      return parsed
          .map((method) =>
              method.copyWith(isDefault: method.id == resolvedDefaultId))
          .toList(growable: false);
    } catch (_) {
      return const <PaymentMethodModel>[];
    }
  }

  static Future<void> savePaymentMethods(
    List<PaymentMethodModel> methods,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (methods.isEmpty) {
      await prefs.remove(_paymentMethodsKey);
      await prefs.remove(_defaultPaymentMethodIdKey);
      return;
    }

    final defaultId = methods
        .firstWhere((method) => method.isDefault, orElse: () => methods.first)
        .id;
    final serializable = methods
        .map((method) => method.copyWith(isDefault: false).toJson())
        .toList(growable: false);

    await prefs.setString(_paymentMethodsKey, jsonEncode(serializable));
    await prefs.setString(_defaultPaymentMethodIdKey, defaultId);
  }
}
