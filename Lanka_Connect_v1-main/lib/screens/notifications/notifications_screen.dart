import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/notification_service.dart';
import '../../utils/user_roles.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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

    final body = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.users().doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        final role = UserRoles.normalize(userSnapshot.data?.data()?['role']);
        final includeAdminChannel = role == UserRoles.admin;
        final recipientIds = includeAdminChannel
            ? [user.uid, NotificationService.adminChannelRecipientId]
            : [user.uid];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreRefs.notifications()
              .where('recipientId', whereIn: recipientIds)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  FirestoreErrorHandler.toUserMessage(snapshot.error!),
                ),
              );
            }

            final docs = [...(snapshot.data?.docs ?? [])];
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

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final title = (data['title'] ?? 'Notification').toString();
                final body = (data['body'] ?? '').toString();
                final isRead = (data['isRead'] ?? false) == true;
                final scheme = Theme.of(context).colorScheme;

                return ListTile(
                  leading: Icon(
                    isRead ? Icons.notifications_none : Icons.notifications,
                    color: isRead ? scheme.onSurfaceVariant : scheme.primary,
                  ),
                  title: Text(title, style: TextStyle(color: scheme.onSurface)),
                  subtitle: Text(
                    body,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  trailing: isRead
                      ? null
                      : TextButton(
                          onPressed: () => _markRead(context, doc.id),
                          child: Text(
                            'Mark read',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ),
                );
              },
            );
          },
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
