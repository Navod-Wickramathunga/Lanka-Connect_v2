import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/theme/design_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/display_name_utils.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/notification_service.dart';
import '../../utils/user_roles.dart';
import '../chat/chat_screen.dart';
import '../payments/payment_screen.dart';
import '../reviews/review_form_screen.dart';

class BookingListScreen extends StatelessWidget {
  const BookingListScreen({super.key});

  // Status color mapping matching React STATUS_COLORS
  static const Map<String, Color> _statusColors = {
    'pending': Color(0xFFF97316), // orange
    'accepted': Color(0xFF3B82F6), // blue
    'completed': Color(0xFF22C55E), // green
    'cancelled': Color(0xFF64748B), // slate
    'rejected': Color(0xFFEF4444), // red
  };

  static const Map<String, IconData> _statusIcons = {
    'pending': Icons.schedule,
    'accepted': Icons.check_circle_outline,
    'completed': Icons.task_alt,
    'cancelled': Icons.cancel_outlined,
    'rejected': Icons.block,
  };

  Color _colorForStatus(String status) =>
      _statusColors[status.toLowerCase()] ?? DesignTokens.textSubtle;

  IconData _iconForStatus(String status) =>
      _statusIcons[status.toLowerCase()] ?? Icons.help_outline;

  String _shortId(String id, {int length = 8}) {
    final value = id.trim();
    if (value.isEmpty) return 'Unknown';
    final take = value.length < length ? value.length : length;
    return value.substring(0, take);
  }

  Future<void> _confirmCancel(
    BuildContext context,
    String bookingId,
    String seekerId,
    String providerId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) {
      await _updateStatus(
        context,
        bookingId,
        'cancelled',
        seekerId,
        providerId,
      );
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    String bookingId,
    String status,
    String seekerId,
    String providerId,
  ) async {
    try {
      await FirestoreRefs.bookings().doc(bookingId).update({'status': status});
      await NotificationService.createMany(
        recipientIds: [seekerId, providerId],
        title: 'Booking status updated',
        body:
            'Booking ${bookingId.substring(0, bookingId.length > 6 ? 6 : bookingId.length)} is now "$status".',
        type: 'booking',
        data: {'bookingId': bookingId, 'status': status},
      );
      await NotificationService.notifyAdmins(
        title: 'Booking status changed',
        body: 'Booking status changed to "$status".',
        data: {
          'bookingId': bookingId,
          'status': status,
          'providerId': providerId,
          'seekerId': seekerId,
        },
      );
    } on FirebaseException catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'bookings_update_status',
        error: e,
        stackTrace: st,
        details: {'bookingId': bookingId, 'status': status},
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    } catch (e, st) {
      FirestoreErrorHandler.logWriteError(
        operation: 'bookings_update_status_unknown',
        error: e,
        stackTrace: st,
        details: {'bookingId': bookingId, 'status': status},
      );
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          FirestoreErrorHandler.toUserMessage(e),
        );
      }
    }
  }

  Widget _enhancedStatusBadge(String status) {
    final color = _colorForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
        final role = user.isAnonymous
            ? UserRoles.guest
            : UserRoles.normalize(snapshot.data?.data()?['role']);
        final isSeekerLike = role == UserRoles.seeker || role == UserRoles.guest;

        Query<Map<String, dynamic>> query = FirestoreRefs.bookings();
        if (role == UserRoles.admin) {
          // Admin sees all bookings (no filter)
        } else if (role == UserRoles.provider) {
          query = query.where('providerId', isEqualTo: user.uid);
        } else {
          query = query.where('seekerId', isEqualTo: user.uid);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, bookingSnapshot) {
            if (bookingSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (bookingSnapshot.hasError) {
              return Center(
                child: Text(
                  FirestoreErrorHandler.toUserMessage(bookingSnapshot.error!),
                ),
              );
            }

            final docs = bookingSnapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              if (!kIsWeb) {
                return MobilePageScaffold(
                  title: 'Bookings',
                  subtitle: 'Track the lifecycle of your bookings',
                  accentColor: RoleVisuals.forRole(role).accent,
                  body: const MobileEmptyState(
                    title: 'No bookings yet.',
                    icon: Icons.event_busy,
                  ),
                );
              }
              return const WebPageScaffold(
                title: 'Bookings',
                subtitle: 'Track the lifecycle of your current bookings.',
                useScaffold: false,
                child: Center(child: Text('No bookings yet.')),
              );
            }

            final list = ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final status = data['status']?.toString() ?? 'pending';
                final serviceId = data['serviceId']?.toString() ?? 'Unknown';
                final amount = (data['amount'] is num)
                    ? (data['amount'] as num).toDouble()
                    : null;
                final statusColor = _colorForStatus(status);
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  elevation: 2,
                  shadowColor: statusColor.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: statusColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
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
                        fallback:
                            (serviceData['location'] ?? 'Location not set')
                                .toString(),
                      );

                      final readableTitle = serviceTitle.isNotEmpty
                          ? serviceTitle
                          : 'Service ${_shortId(serviceId)}';

                      return Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row: status icon + title + badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _colorForStatus(
                                      status,
                                    ).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconForStatus(status),
                                    size: 20,
                                    color: _colorForStatus(status),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        readableTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      if (category.isNotEmpty)
                                        Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                _enhancedStatusBadge(status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (location.trim().isNotEmpty)
                              _infoRow(context, Icons.location_on, location),
                            if (amount != null)
                              _infoRow(
                                context,
                                Icons.payments,
                                'LKR ${amount.toStringAsFixed(0)}',
                              ),
                            const Divider(height: 20),
                            // Action buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _actionChip(
                                  context: context,
                                  icon: Icons.chat_bubble_outline,
                                  label: 'Chat',
                                  color: DesignTokens.info,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChatScreen(chatId: doc.id),
                                    ),
                                  ),
                                ),
                                if (role == UserRoles.provider &&
                                    status == 'pending')
                                  _actionChip(
                                    context: context,
                                    icon: Icons.check,
                                    label: 'Accept',
                                    color: const Color(0xFF22C55E),
                                    onTap: () => _updateStatus(
                                      context,
                                      doc.id,
                                      'accepted',
                                      (data['seekerId'] ?? '').toString(),
                                      (data['providerId'] ?? '').toString(),
                                    ),
                                  ),
                                if (role == UserRoles.provider &&
                                    status == 'pending')
                                  _actionChip(
                                    context: context,
                                    icon: Icons.close,
                                    label: 'Reject',
                                    color: const Color(0xFFEF4444),
                                    onTap: () => _updateStatus(
                                      context,
                                      doc.id,
                                      'rejected',
                                      (data['seekerId'] ?? '').toString(),
                                      (data['providerId'] ?? '').toString(),
                                    ),
                                  ),
                                if (role == UserRoles.provider &&
                                    status == 'accepted')
                                  _actionChip(
                                    context: context,
                                    icon: Icons.task_alt,
                                    label: 'Complete',
                                    color: const Color(0xFF22C55E),
                                    onTap: () => _updateStatus(
                                      context,
                                      doc.id,
                                      'completed',
                                      (data['seekerId'] ?? '').toString(),
                                      (data['providerId'] ?? '').toString(),
                                    ),
                                  ),
                                if (isSeekerLike &&
                                    status == 'accepted')
                                  _actionChip(
                                    context: context,
                                    icon: Icons.payment,
                                    label: 'Pay',
                                    color: DesignTokens.brandPrimary,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PaymentScreen(bookingId: doc.id),
                                      ),
                                    ),
                                  ),
                                if ((isSeekerLike &&
                                        status == 'pending') ||
                                    (role == UserRoles.provider &&
                                        status == 'accepted'))
                                  _actionChip(
                                    context: context,
                                    icon: Icons.cancel_outlined,
                                    label: 'Cancel',
                                    color: const Color(0xFFEF4444),
                                    onTap: () => _confirmCancel(
                                      context,
                                      doc.id,
                                      (data['seekerId'] ?? '').toString(),
                                      (data['providerId'] ?? '').toString(),
                                    ),
                                  ),
                                if (isSeekerLike &&
                                    status == 'completed' &&
                                    data['reviewed'] != true)
                                  _actionChip(
                                    context: context,
                                    icon: Icons.rate_review,
                                    label: 'Review',
                                    color: DesignTokens.brandSecondary,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ReviewFormScreen(
                                          bookingId: doc.id,
                                          serviceId: (data['serviceId'] ?? '')
                                              .toString(),
                                          providerId: (data['providerId'] ?? '')
                                              .toString(),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isSeekerLike &&
                                    status == 'completed' &&
                                    data['reviewed'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF22C55E,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 14,
                                          color: const Color(0xFF22C55E),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Reviewed',
                                          style: TextStyle(
                                            color: Color(0xFF22C55E),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
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
                title: 'Bookings',
                subtitle: 'Track the lifecycle of your bookings',
                accentColor: RoleVisuals.forRole(role).accent,
                body: list,
              );
            }

            return WebPageScaffold(
              title: 'Bookings',
              subtitle: 'Track the lifecycle of your current bookings.',
              useScaffold: false,
              child: list,
            );
          },
        );
      },
    );
  }
}
