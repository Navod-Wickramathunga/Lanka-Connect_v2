import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_refs.dart';

class PresenceService {
  const PresenceService._();

  static const Duration onlineWindow = Duration(minutes: 5);

  static Future<void> markOnline(String uid) async {
    if (uid.trim().isEmpty) return;
    await FirestoreRefs.users().doc(uid).set({
      'isOnline': true,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> markOffline(String uid) async {
    if (uid.trim().isEmpty) return;
    await FirestoreRefs.users().doc(uid).set({
      'isOnline': false,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static bool isOnline(Map<String, dynamic>? data, {DateTime? now}) {
    if (data == null) return false;
    final stamp = data['lastSeenAt'];
    if (stamp is! Timestamp) return false;
    final isMarkedOnline = (data['isOnline'] ?? false) == true;
    final elapsed = (now ?? DateTime.now()).difference(stamp.toDate());
    return isMarkedOnline && elapsed <= onlineWindow;
  }

  static String statusLabel(Map<String, dynamic>? data, {DateTime? now}) {
    if (isOnline(data, now: now)) return 'Online now';
    final stamp = data?['lastSeenAt'];
    if (stamp is! Timestamp) return 'Offline';
    final elapsed = (now ?? DateTime.now()).difference(stamp.toDate());
    if (elapsed.inMinutes < 1) return 'Seen just now';
    if (elapsed.inMinutes < 60) return 'Seen ${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return 'Seen ${elapsed.inHours}h ago';
    return 'Seen ${elapsed.inDays}d ago';
  }
}
