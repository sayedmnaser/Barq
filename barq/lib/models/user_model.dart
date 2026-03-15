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
      created: DateTime.tryParse(record.getStringValue('created')) ??
          DateTime.now(),
      updated: DateTime.tryParse(record.getStringValue('updated')) ??
          DateTime.now(),
    );
  }

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
