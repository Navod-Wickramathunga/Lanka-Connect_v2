import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/display_name_utils.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/user_roles.dart';

/// Screen for seekers to track the status of their submitted service requests.
class SeekerRequestListScreen extends StatelessWidget {
  const SeekerRequestListScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return MobileTokens.accent;
    }
  }

  Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.block;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    final query = FirestoreRefs.requests()
        .where('seekerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(FirestoreErrorHandler.toUserMessage(snapshot.error!)),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          if (!kIsWeb) {
            return MobilePageScaffold(
              title: 'My Requests',
              subtitle: 'Track your service requests',
              accentColor: RoleVisuals.forRole(UserRoles.seeker).accent,
              body: const MobileEmptyState(
                title: 'No service requests yet.',
                icon: Icons.inbox,
                subtitle:
                    'Browse services and submit a request\nto get started.',
              ),
            );
          }
          return const WebPageScaffold(
            title: 'My Requests',
            subtitle: 'Track your service requests.',
            useScaffold: false,
            child: Center(child: Text('No service requests yet.')),
          );
        }

        final list = ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final serviceId = data['serviceId']?.toString() ?? 'Unknown';
            final providerId = data['providerId']?.toString() ?? '';
            final status = (data['status'] ?? 'pending').toString();
            final createdAt = data['createdAt'];
            String timeAgo = '';
            if (createdAt is Timestamp) {
              final diff = DateTime.now().difference(createdAt.toDate());
              if (diff.inDays > 0) {
                timeAgo = '${diff.inDays}d ago';
              } else if (diff.inHours > 0) {
                timeAgo = '${diff.inHours}h ago';
              } else {
                timeAgo = '${diff.inMinutes}m ago';
              }
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirestoreRefs.services().doc(serviceId).snapshots(),
                builder: (context, serviceSnapshot) {
                  final serviceData = serviceSnapshot.data?.data() ?? {};
                  final serviceTitle = (serviceData['title'] ?? '')
                      .toString()
                      .trim();
                  final category = (serviceData['category'] ?? '')
                      .toString()
                      .trim();
                  final city = serviceData['city'];
                  final district = serviceData['district'];
                  final location = DisplayNameUtils.locationLabel(
                    city: city,
                    district: district,
                    fallback: (serviceData['location'] ?? '').toString(),
                  );

                  final readableTitle = serviceTitle.isNotEmpty
                      ? serviceTitle
                      : 'Service ${serviceId.length > 8 ? serviceId.substring(0, 8) : serviceId}';

                  final subtitleParts = <String>[
                    if (category.isNotEmpty) category,
                    if (location.trim().isNotEmpty) location,
                    if (timeAgo.isNotEmpty) timeAgo,
                  ];

                  final notes = (data['notes'] ?? '').toString().trim();
                  final timeWindow = (data['timeWindow'] ?? '')
                      .toString()
                      .trim();
                  final scheduledDate = (data['scheduledDate'] ?? '')
                      .toString()
                      .trim();

                  return Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      leading: Icon(
                        _statusIcon(status),
                        color: _statusColor(status),
                        size: 20,
                      ),
                      title: Text(
                        readableTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitleParts.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitleParts.join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                      trailing: MobileStatusChip(
                        label: status.toUpperCase(),
                        color: _statusColor(status),
                      ),
                      children: [
                        // Provider name
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirestoreRefs.users()
                              .doc(providerId)
                              .snapshots(),
                          builder: (context, providerSnap) {
                            final providerName =
                                providerSnap.data?.data()?['displayName'] ??
                                providerSnap.data?.data()?['name'] ??
                                'Provider';
                            return _detailRow(
                              context,
                              Icons.person_outline,
                              'Provider',
                              providerName.toString(),
                            );
                          },
                        ),
                        if (timeWindow.isNotEmpty)
                          _detailRow(
                            context,
                            Icons.schedule,
                            'Time window',
                            timeWindow,
                          ),
                        if (scheduledDate.isNotEmpty)
                          _detailRow(
                            context,
                            Icons.calendar_today,
                            'Scheduled',
                            scheduledDate,
                          ),
                        if (notes.isNotEmpty)
                          _detailRow(context, Icons.notes, 'Notes', notes),
                        if (status == 'accepted') ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'A booking has been created for this request.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );

        if (!kIsWeb) {
          return MobilePageScaffold(
            title: 'My Requests',
            subtitle: 'Track your service requests',
            accentColor: RoleVisuals.forRole(UserRoles.seeker).accent,
            body: list,
          );
        }

        return WebPageScaffold(
          title: 'My Requests',
          subtitle: 'Track your service requests.',
          useScaffold: false,
          child: list,
        );
      },
    );
  }
}
