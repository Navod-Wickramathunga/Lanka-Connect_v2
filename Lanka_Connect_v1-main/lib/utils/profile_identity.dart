import 'package:firebase_auth/firebase_auth.dart';

class ProfileIdentity {
  const ProfileIdentity._();

  static String displayNameFrom(
    Map<String, dynamic>? data, {
    User? authUser,
    String fallback = 'User',
  }) {
    final explicit = (data?['displayName'] ?? data?['name'] ?? '')
        .toString()
        .trim();
    if (explicit.isNotEmpty) return explicit;
    final authName = (authUser?.displayName ?? '').trim();
    if (authName.isNotEmpty) return authName;
    final email = (authUser?.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return fallback;
  }

  static String profileImageUrlFrom(
    Map<String, dynamic>? data, {
    User? authUser,
  }) {
    final explicit = (data?['imageUrl'] ?? '').toString().trim();
    if (explicit.isNotEmpty) return explicit;
    return (authUser?.photoURL ?? '').trim();
  }
}
