import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/app_feedback.dart';
import '../../utils/display_name_utils.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/notification_service.dart';
import '../../utils/user_roles.dart';

/// Dedicated screen for providers to manage incoming service requests.
/// Shows pending requests with accept / reject actions.
/// Accepting a request automatically creates a booking.
class RequestListScreen extends StatelessWidget {
  const RequestListScreen({super.key});

  String _shortId(String id, {int length = 8}) {
    final value = id.trim();
    if (value.isEmpty) return 'Unknown';
    final take = value.length < length ? value.length : length;
    return value.substring(0, take);
  }

  Future<void> _updateStatus(
    BuildContext context,
    String requestId,
    String status,
    String seekerId,
    String providerId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      // Update request status
      await FirestoreRefs.requests().doc(requestId).update({'status': status});

      // If accepted, create a booking from the request data
      if (status == 'accepted') {
        final serviceId = (requestData['serviceId'] ?? '').toString();
        // Look up the service price
        double amount = 0;
        if (serviceId.isNotEmpty) {
          final serviceDoc = await FirestoreRefs.services()
              .doc(serviceId)
              .get();
          final serviceData = serviceDoc.data();
          if (serviceData != null && serviceData['price'] is num) {
            amount = (serviceData['price'] as num).toDouble();
          }
        }

        final bookingRef = await FirestoreRefs.bookings().add({
          'serviceId': serviceId,
          'providerId': providerId,
          'seekerId': seekerId,
          'amount': amount,
          'status': 'accepted',
          'fromRequestId': requestId,
          'notes': (requestData['notes'] ?? '').toString(),
          if (requestData['scheduledDate'] is Timestamp)
            'scheduledDate': requestData['scheduledDate'],
          if ((requestData['scheduledDateKey'] ?? '').toString().isNotEmpty)
            'scheduledDateKey': requestData['scheduledDateKey'],
          if ((requestData['timeWindow'] ?? '').toString().isNotEmpty)
            'timeWindow': requestData['timeWindow'],
          'createdAt': FieldValue.serverTimestamp(),
        });

        await NotificationService.createMany(
          recipientIds: [seekerId, providerId],
          title: 'Request accepted — booking created',
          body:
              'Your service request has been accepted. A booking has been created.',
          type: 'booking',
          data: {
            'requestId': requestId,
            'bookingId': bookingRef.id,
            'status': 'accepted',
          },
        );
      } else {
        await NotificationService.createMany(
          recipientIds: [seekerId, providerId],
          title: 'Service request $status',
          body: 'Your service request has been $status.',
          type: 'request',
          data: {'requestId': requestId, 'status': status},
        );
      }

      await NotificationService.notifyAdmins(
        title: 'Request $status',
        body: 'A service request was $status by the provider.',
        data: {
          'requestId': requestId,
          'status': status,
          'providerId': providerId,
          'seekerId': seekerId,
        },
      );
      if (context.mounted) {
        TigerFeedback.show(
          context,
          status == 'accepted'
              ? 'Tiger approved the request and created a booking.'
              : 'Tiger marked the request as $status.',
          tone: TigerFeedbackTone.success,
        );
      }
    } on FirebaseException catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'request_update_status',
        error: e,
        stackTrace: st,
        details: {'requestId': requestId, 'status': status},
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'request_update_status_unknown',
        error: e,
        stackTrace: st,
        details: {'requestId': requestId, 'status': status},
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    final query = FirestoreRefs.requests()
        .where('providerId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending');

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
              title: 'Requests',
              subtitle: 'Incoming booking requests',
              accentColor: RoleVisuals.forRole(UserRoles.provider).accent,
              body: const MobileEmptyState(
                title: 'No pending requests.',
                icon: Icons.inbox,
                subtitle:
                    'New booking requests from seekers\nwill appear here.',
              ),
            );
          }
          return const WebPageScaffold(
            title: 'Requests',
            subtitle: 'Incoming booking requests.',
            useScaffold: false,
            child: Center(child: Text('No pending requests.')),
          );
        }

        final list = ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final serviceId = data['serviceId']?.toString() ?? 'Unknown';
            final seekerId = data['seekerId']?.toString() ?? '';
            final providerId = data['providerId']?.toString() ?? '';
            final amount = (data['amount'] is num)
                ? (data['amount'] as num).toDouble()
                : null;
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
                      : 'Service ${_shortId(serviceId)}';

                  final subtitleParts = <String>[
                    if (category.isNotEmpty) category,
                    if (location.trim().isNotEmpty) location,
                    if (amount != null) 'LKR ${amount.toStringAsFixed(0)}',
                    if (timeAgo.isNotEmpty) timeAgo,
                  ];

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          readableTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitleParts.join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        // Seeker name
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirestoreRefs.users()
                              .doc(seekerId)
                              .snapshots(),
                          builder: (context, seekerSnap) {
                            final seekerName =
                                seekerSnap.data?.data()?['displayName'] ??
                                'Seeker';
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'From: $seekerName',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accept'),
                              onPressed: () => _updateStatus(
                                context,
                                doc.id,
                                'accepted',
                                seekerId,
                                providerId,
                                data,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              onPressed: () => _updateStatus(
                                context,
                                doc.id,
                                'rejected',
                                seekerId,
                                providerId,
                                data,
                              ),
                            ),
                          ],
                        ),
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
            title: 'Requests',
            subtitle: 'Incoming booking requests',
            accentColor: RoleVisuals.forRole(UserRoles.provider).accent,
            body: list,
          );
        }

        return WebPageScaffold(
          title: 'Requests',
          subtitle: 'Incoming booking requests.',
          useScaffold: false,
          child: list,
        );
      },
    );
  }
}
