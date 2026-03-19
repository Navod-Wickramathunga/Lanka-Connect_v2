import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_refs.dart';

class NotificationService {
  static const String adminChannelRecipientId = '__admins__';

  static Future<void> createMany({
    required List<String> recipientIds,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic> data = const {},
    bool excludeSender = false,
  }) async {
    final senderId = FirebaseAuth.instance.currentUser?.uid;
    if (senderId == null || recipientIds.isEmpty) {
      debugPrint(
        'Notification createMany skipped: sender missing or recipient list empty.',
      );
      return;
    }

    final recipients = recipientIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (excludeSender) {
      recipients.remove(senderId);
    }
    if (recipients.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final recipientId in recipients) {
        final ref = FirestoreRefs.notifications().doc();
        batch.set(ref, {
          'recipientId': recipientId,
          'senderId': senderId,
          'title': title,
          'body': body,
          'type': type,
          'data': data,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e, st) {
      debugPrint('Notification createMany failed: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  static Future<void> createManySafe({
    required List<String> recipientIds,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic> data = const {},
    bool excludeSender = false,
  }) async {
    try {
      await createMany(
        recipientIds: recipientIds,
        title: title,
        body: body,
        type: type,
        data: data,
        excludeSender: excludeSender,
      );
    } catch (e, st) {
      debugPrint('Notification createManySafe suppressed: $e');
      debugPrint(st.toString());
    }
  }

  static Future<void> create({
    required String recipientId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic> data = const {},
  }) async {
    final senderId = FirebaseAuth.instance.currentUser?.uid;
    if (senderId == null || recipientId.isEmpty) {
      debugPrint(
        'Notification create skipped: sender missing or recipient empty.',
      );
      return;
    }

    try {
      await FirestoreRefs.notifications().add({
        'recipientId': recipientId,
        'senderId': senderId,
        'title': title,
        'body': body,
        'type': type,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('Notification create failed: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  static Future<void> createSafe({
    required String recipientId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic> data = const {},
  }) async {
    try {
      await create(
        recipientId: recipientId,
        title: title,
        body: body,
        type: type,
        data: data,
      );
    } catch (e, st) {
      debugPrint('Notification createSafe suppressed: $e');
      debugPrint(st.toString());
    }
  }

  static Future<void> notifyAdmins({
    required String title,
    required String body,
    String type = 'admin_event',
    Map<String, dynamic> data = const {},
  }) async {
    await create(
      recipientId: adminChannelRecipientId,
      title: title,
      body: body,
      type: type,
      data: data,
    );
  }

  static Future<void> notifyAdminsSafe({
    required String title,
    required String body,
    String type = 'admin_event',
    Map<String, dynamic> data = const {},
  }) async {
    await createSafe(
      recipientId: adminChannelRecipientId,
      title: title,
      body: body,
      type: type,
      data: data,
    );
  }
}
