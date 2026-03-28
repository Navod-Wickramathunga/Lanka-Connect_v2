import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/fcm_service.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../widgets/notification_panel_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Map<String, dynamic> _payloadFor(Map<String, dynamic> data) {
    final payload = <String, dynamic>{'type': (data['type'] ?? '').toString()};
    final raw = data['data'];
    if (raw is Map) {
      raw.forEach((key, value) {
        payload[key.toString()] = value;
      });
    }
    return payload;
  }

  String _timeLabel(Timestamp? value) {
    if (value == null) return '';
    final diff = DateTime.now().difference(value.toDate());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _markRead(BuildContext context, String id) async {
    try {
      await FirestoreRefs.notifications().doc(id).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!context.mounted) return;
      FirestoreErrorHandler.showError(
        context,
        FirestoreErrorHandler.toUserMessage(e),
      );
    }
  }

  Future<void> _deleteNotification(BuildContext context, String id) async {
    try {
      await FirestoreRefs.notifications().doc(id).delete();
    } catch (e) {
      if (!context.mounted) return;
      FirestoreErrorHandler.showError(
        context,
        FirestoreErrorHandler.toUserMessage(e),
      );
    }
  }

  Future<void> _markAllRead(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in docs.where(
        (item) => (item.data()['isRead'] ?? false) != true,
      )) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      if (!context.mounted) return;
      FirestoreErrorHandler.showError(
        context,
        FirestoreErrorHandler.toUserMessage(e),
      );
    }
  }

  Future<void> _clearAllNotifications(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      if (!context.mounted) return;
      FirestoreErrorHandler.showError(
        context,
        FirestoreErrorHandler.toUserMessage(e),
      );
    }
  }

  Future<void> _showNotificationDetails(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    await _markRead(context, doc.id);
    if (!context.mounted) return;

    final payload = _payloadFor(data);
    final createdAt = data['createdAt'] as Timestamp?;
    final rawDetailData = data['data'];
    final detailData = rawDetailData is Map ? rawDetailData : const {};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text((data['title'] ?? 'Notification').toString()),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text((data['body'] ?? '').toString()),
                  const SizedBox(height: 16),
                  Text(
                    'Type: ${(data['type'] ?? 'general').toString()}',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Created: ${createdAt.toDate().toLocal()}',
                      style: Theme.of(dialogContext).textTheme.bodyMedium,
                    ),
                  ],
                  if (detailData.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Related details',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...detailData.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${entry.key}: ${entry.value}'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _deleteNotification(dialogContext, doc.id),
              child: const Text('Remove'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await FcmService.navigateFromPayload(payload);
              },
              child: const Text('Open related page'),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final unreadCount = docs
        .where((doc) => (doc.data()['isRead'] ?? false) != true)
        .length;
    return NotificationToolbar(
      unreadCount: unreadCount,
      hasNotifications: docs.isNotEmpty,
      onMarkAllRead: () => _markAllRead(context, docs),
      onClearAll: () => _clearAllNotifications(context, docs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kIsWeb) {
        return const WebPageScaffold(
          title: 'Notifications',
          subtitle: 'Stay updated with booking, service, and payment events.',
          useScaffold: true,
          child: Center(child: Text('Not signed in')),
        );
      }
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.notifications()
          .where('recipientId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(FirestoreErrorHandler.toUserMessage(snapshot.error!)),
          );
        }

        final docs = [
          ...(snapshot.data?.docs ?? []),
        ].where((doc) {
          return (doc.data()['recipientId'] ?? '').toString() == user.uid;
        }).toList();
        docs.sort((a, b) {
          final aTs = a.data()['createdAt'] as Timestamp?;
          final bTs = b.data()['createdAt'] as Timestamp?;
          final aMs = aTs?.millisecondsSinceEpoch ?? 0;
          final bMs = bTs?.millisecondsSinceEpoch ?? 0;
          return bMs.compareTo(aMs);
        });
        if (docs.isEmpty) {
          if (kIsWeb) {
            return const Center(child: Text('No notifications yet.'));
          }
          return const MobileEmptyState(
            title: 'No notifications yet.',
            icon: Icons.notifications_none,
            subtitle:
                'You\u2019ll be notified about bookings,\nmessages, and important updates here.',
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final title = (data['title'] ?? 'Notification').toString();
                  final body = (data['body'] ?? '').toString();
                  final isRead = (data['isRead'] ?? false) == true;
                  final type = (data['type'] ?? 'general').toString();
                  final createdAt = data['createdAt'] as Timestamp?;
                  return NotificationListItem(
                    title: title,
                    body: body,
                    type: type,
                    timeLabel: createdAt == null ? '' : _timeLabel(createdAt),
                    isRead: isRead,
                    onOpen: () => _showNotificationDetails(context, doc),
                    onViewDetails: () => _showNotificationDetails(context, doc),
                    onRemove: () => _deleteNotification(context, doc.id),
                  );
                },
              ),
            ),
            _toolbar(context, docs),
          ],
        );
      },
    );

    if (kIsWeb) {
      return WebPageScaffold(
        title: 'Notifications',
        subtitle: 'Stay updated with booking, service, and payment events.',
        useScaffold: true,
        child: body,
      );
    }

    return MobilePageScaffold(
      title: 'Notifications',
      subtitle: 'Stay updated with booking, service, and payment events.',
      accentColor: MobileTokens.primary,
      useScaffold: true,
      body: body,
    );
  }
}
