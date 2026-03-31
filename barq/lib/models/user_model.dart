import 'package:pocketbase/pocketbase.dart';

/// Dart model that maps to the PocketBase `users` (Auth) collection.
class User {
  const User({
    required this.id,
    required this.email,
    required this.emailVisibility,
    required this.verified,
    required this.name,
    this.avatar,
    required this.phoneNumber,
    required this.role,
    required this.created,
    required this.updated,
  });

  final String id;
  final String email;
  final bool emailVisibility;
  final bool verified;
  final String name;
  final String? avatar;
  final int phoneNumber;
  final String role;
  final DateTime created;
  final DateTime updated;

  /// Build a [User] from a PocketBase [RecordModel].
  factory User.fromRecord(RecordModel record) {
    return User(
      id: record.id,
      email: record.getStringValue('email'),
      emailVisibility: record.getBoolValue('emailVisibility'),
      verified: record.getBoolValue('verified'),
      name: record.getStringValue('name'),
      avatar: record.getStringValue('avatar').isNotEmpty
          ? record.getStringValue('avatar')
          : null,
      phoneNumber: record.getIntValue('phoneNumber'),
      role: resolveRoleFromRecord(record),
      created:
          DateTime.tryParse(record.getStringValue('created')) ?? DateTime.now(),
      updated:
          DateTime.tryParse(record.getStringValue('updated')) ?? DateTime.now(),
    );
  }

  static String resolveRoleFromRecord(RecordModel record) {
    const booleanDriverCandidates = <String>[
      'driver',
      'Driver',
      'is_driver',
      'isDriver',
    ];

    // If any boolean driver flag is true, treat the account as driver.
    for (final field in booleanDriverCandidates) {
      if (record.getBoolValue(field)) {
        return 'driver';
      }
    }

    final roleCandidates = <String>[
      record.getStringValue('role'),
      record.getStringValue('account_type'),
      record.getStringValue('accountType'),
      record.getStringValue('user_type'),
      record.getStringValue('userType'),
      record.getStringValue('type'),
    ];

    for (final candidate in roleCandidates) {
      if (candidate.trim().isNotEmpty) {
        return normalizeRole(candidate);
      }
    }

    return 'customer';
  }

  static String normalizeRole(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized == 'driver' || normalized == 'tow_driver') {
      return 'driver';
    }
    if (normalized.isEmpty ||
        normalized == 'customer' ||
        normalized == 'user') {
      return 'customer';
    }
    return normalized;
  }

  bool get isDriver => role == 'driver';

  /// Returns the first name (first word of [name]).
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : 'User';
  }

  /// Returns the last name (everything after the first word of [name]).
  String get lastName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  /// Full avatar URL from PocketBase, or `null` if no avatar is set.
  String? avatarUrl(String baseUrl) {
    if (avatar == null) return null;
    return '$baseUrl/api/files/users/$id/$avatar';
  }
}
