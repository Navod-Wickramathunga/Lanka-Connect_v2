import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/user_roles.dart';
import 'chat_screen.dart';
import '../../widgets/shimmer_loading.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return MobileTokens.secondary;
      case 'completed':
        return MobileTokens.primary;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      default:
        return MobileTokens.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.users().doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final role = UserRoles.normalize(snapshot.data?.data()?['role']);

        Query<Map<String, dynamic>> query = FirestoreRefs.bookings();
        if (role == UserRoles.provider) {
          query = query.where('providerId', isEqualTo: user.uid);
        } else {
          query = query.where('seekerId', isEqualTo: user.uid);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, bookingSnapshot) {
            if (bookingSnapshot.connectionState == ConnectionState.waiting) {
              return const ShimmerCardList(itemCount: 4);
            }
            if (bookingSnapshot.hasError) {
              return Center(
                child: Text('Failed to load chats: ${bookingSnapshot.error}'),
              );
            }

            final docs = bookingSnapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              if (!kIsWeb) {
                return MobilePageScaffold(
                  title: 'Chats',
                  subtitle: 'Messages from your active bookings',
                  accentColor: RoleVisuals.forRole(role).accent,
                  body: const MobileEmptyState(
                    title: 'No chats yet.',
                    icon: Icons.chat_bubble_outline,
                    subtitle:
                        'Conversations with seekers and providers\nwill show up once a booking is active.',
                  ),
                );
              }
              return const WebPageScaffold(
                title: 'Chats',
                subtitle:
                    'Open booking conversations with seekers and providers.',
                useScaffold: false,
                child: Center(child: Text('No chats yet.')),
              );
            }

            final list = ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final status = data['status']?.toString() ?? 'Unknown';
                final serviceId = data['serviceId']?.toString() ?? '';
                final providerId = data['providerId']?.toString() ?? '';
                final seekerId = data['seekerId']?.toString() ?? '';
                final otherPartyId = role == UserRoles.provider
                    ? seekerId
                    : providerId;

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirestoreRefs.services().doc(serviceId).snapshots(),
                  builder: (context, serviceSnap) {
                    final serviceTitle =
                        (serviceSnap.data?.data()?['title']?.toString() ?? '')
                            .trim();
                    final displayTitle = serviceTitle.isNotEmpty
                        ? serviceTitle
                        : 'Chat';

                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream: FirestoreRefs.users()
                          .doc(otherPartyId)
                          .snapshots(),
                      builder: (context, userSnap) {
                        final otherName =
                            userSnap.data?.data()?['displayName']?.toString() ??
                            userSnap.data?.data()?['name']?.toString() ??
                            (role == UserRoles.provider
                                ? 'Seeker'
                                : 'Provider');
                        final trimmedOtherName = otherName.trim();
                        final avatarInitial = trimmedOtherName.isNotEmpty
                            ? trimmedOtherName[0].toUpperCase()
                            : '?';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.45),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(
                                status,
                              ).withValues(alpha: 0.15),
                              child: Text(
                                avatarInitial,
                                style: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              displayTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(otherName),
                                const SizedBox(height: 4),
                                MobileStatusChip(
                                  label: status,
                                  color: _statusColor(status),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chat_bubble_outline),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(chatId: doc.id),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );

            if (!kIsWeb) {
              return MobilePageScaffold(
                title: 'Chats',
                subtitle: 'Messages from your active bookings',
                accentColor: RoleVisuals.forRole(role).accent,
                body: list,
              );
            }
            return WebPageScaffold(
              title: 'Chats',
              subtitle:
                  'Open booking conversations with seekers and providers.',
              useScaffold: false,
              child: list,
            );
          },
        );
      },
    );
  }
}
