import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/theme/design_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/app_feedback.dart';
import '../../utils/display_name_utils.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/notification_service.dart';
import '../../utils/user_roles.dart';
import '../payments/payment_history_screen.dart';
import '../chat/chat_screen.dart';
import '../payments/payment_screen.dart';
import '../reviews/review_form_screen.dart';
import '../../widgets/shimmer_loading.dart';

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

  String _formatScheduledDate(dynamic value) {
    if (value is! Timestamp) return '';
    return DateFormat('EEE, d MMM yyyy').format(value.toDate().toLocal());
  }

  bool _isPaymentFinalStatus(String status) =>
      status == 'paid' || status == 'success';

  bool _isPaymentPendingStatus(String status) =>
      status == 'initiated' ||
      status == 'pending_gateway' ||
      status == 'pending_verification';

  String _paymentLabel(String status) {
    switch (status) {
      case 'paid':
      case 'success':
        return 'Paid';
      case 'pending_gateway':
        return 'Checkout started';
      case 'pending_verification':
        return 'Payment verification pending';
      case 'initiated':
        return 'Payment initiated';
      case 'failed':
        return 'Payment failed';
      default:
        return 'Awaiting payment';
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    String bookingId,
    String seekerId,
    String providerId,
    String currentPaymentStatus,
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
        currentPaymentStatus,
      );
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    String bookingId,
    String status,
    String seekerId,
    String providerId,
    String currentPaymentStatus,
  ) async {
    if (status == 'completed' && !_isPaymentFinalStatus(currentPaymentStatus)) {
      FirestoreErrorHandler.showError(
        context,
        'The seeker must complete payment before you can mark this booking as completed.',
      );
      return;
    }

    try {
      await FirestoreRefs.bookings().doc(bookingId).update({'status': status});
      if (!context.mounted) return;
      await NotificationService.createManySafe(
        recipientIds: [seekerId, providerId],
        title: 'Booking status updated',
        body: 'Your booking has been updated to $status.',
        type: 'booking',
        excludeSender: true,
        data: {'bookingId': bookingId, 'status': status},
      );
      await NotificationService.notifyAdminsSafe(
        title: 'Booking status changed',
        body: 'A booking status was changed to $status.',
        data: {
          'bookingId': bookingId,
          'status': status,
          'providerId': providerId,
          'seekerId': seekerId,
        },
      );
      if (!context.mounted) return;
      TigerFeedback.show(
        context,
        status == 'cancelled'
            ? 'Booking cancelled.'
            : 'Booking marked as $status.',
        tone: status == 'cancelled'
            ? TigerFeedbackTone.warning
            : TigerFeedbackTone.success,
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

  void _openPaymentHistory(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()));
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
        final isSeekerLike =
            role == UserRoles.seeker || role == UserRoles.guest;
        final historyActions = isSeekerLike
            ? <Widget>[
                IconButton(
                  onPressed: () => _openPaymentHistory(context),
                  tooltip: 'Payment history',
                  icon: const Icon(Icons.receipt_long_outlined),
                ),
              ]
            : const <Widget>[];

        Query<Map<String, dynamic>> query = FirestoreRefs.bookings();
        if (role == UserRoles.admin) {
          query = query.orderBy('createdAt', descending: true);
        } else if (role == UserRoles.provider) {
          query = query
              .where('providerId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true);
        } else {
          query = query
              .where('seekerId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true);
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, bookingSnapshot) {
            if (bookingSnapshot.connectionState == ConnectionState.waiting) {
              final loadingBody = const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SingleChildScrollView(
                  child: ShimmerCardList(itemCount: 4),
                ),
              );
              if (!kIsWeb) {
                return MobilePageScaffold(
                  title: 'Bookings',
                  subtitle: 'Track the lifecycle of your bookings',
                  accentColor: RoleVisuals.forRole(role).accent,
                  actions: historyActions,
                  body: loadingBody,
                );
              }
              return WebPageScaffold(
                title: 'Bookings',
                subtitle: 'Track the lifecycle of your current bookings.',
                useScaffold: false,
                actions: historyActions,
                child: loadingBody,
              );
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
                  actions: historyActions,
                  body: const MobileEmptyState(
                    title: 'No bookings yet.',
                    icon: Icons.event_busy,
                    subtitle:
                        'Direct bookings and accepted requests\nwill appear here.',
                  ),
                );
              }
              return WebPageScaffold(
                title: 'Bookings',
                subtitle: 'Track the lifecycle of your current bookings.',
                useScaffold: false,
                actions: historyActions,
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
                final scheduledDateLabel = _formatScheduledDate(
                  data['scheduledDate'],
                );
                final paymentStatus = (data['paymentStatus'] ?? '')
                    .toString()
                    .trim();
                final isPaymentComplete = _isPaymentFinalStatus(paymentStatus);
                final isPaymentPending = _isPaymentPendingStatus(paymentStatus);
                final timeWindow = (data['timeWindow'] ?? '').toString().trim();
                final requestedTimeLabel = (data['requestedTimeLabel'] ?? '')
                    .toString()
                    .trim();
                final notes = (data['notes'] ?? '').toString().trim();
                final statusColor = _colorForStatus(status);
                final isTerminalStatus = const [
                  'completed',
                  'cancelled',
                  'rejected',
                ].contains(status);
                return Card(
                  key: ValueKey(doc.id),
                  margin: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isTerminalStatus ? 3 : 6,
                  ),
                  elevation: isTerminalStatus ? 0 : 2,
                  shadowColor: statusColor.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      isTerminalStatus ? 10 : 16,
                    ),
                    side: BorderSide(
                      color: statusColor.withValues(
                        alpha: isTerminalStatus ? 0.15 : 0.25,
                      ),
                      width: isTerminalStatus ? 1 : 1.5,
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

                      // Compact layout for terminal statuses
                      final isTerminal = const [
                        'completed',
                        'cancelled',
                        'rejected',
                      ].contains(status);

                      if (isTerminal) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _iconForStatus(status),
                                size: 18,
                                color: statusColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      readableTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (category.isNotEmpty) ...[
                                          Text(
                                            category,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          if (amount != null)
                                            Text(
                                              '  •  ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                        if (amount != null)
                                          Text(
                                            'LKR ${amount.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Review button or reviewed badge for completed
                              if (status == 'completed' &&
                                  isSeekerLike &&
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
                                )
                              else
                                _enhancedStatusBadge(status),
                            ],
                          ),
                        );
                      }

                      // Full layout for active statuses (pending, accepted)
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
                            if (scheduledDateLabel.isNotEmpty)
                              _infoRow(
                                context,
                                Icons.event_outlined,
                                scheduledDateLabel,
                              ),
                            if (requestedTimeLabel.isNotEmpty)
                              _infoRow(
                                context,
                                Icons.schedule_outlined,
                                requestedTimeLabel,
                              ),
                            if (timeWindow.isNotEmpty)
                              _infoRow(context, Icons.access_time, timeWindow),
                            if (amount != null)
                              _infoRow(
                                context,
                                Icons.payments,
                                'LKR ${amount.toStringAsFixed(0)}',
                              ),
                            if (status == 'accepted')
                              _infoRow(
                                context,
                                isPaymentComplete
                                    ? Icons.verified
                                    : isPaymentPending
                                    ? Icons.hourglass_bottom
                                    : Icons.payments_outlined,
                                'Payment: ${_paymentLabel(paymentStatus)}',
                              ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                notes,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
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
                                      paymentStatus,
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
                                      paymentStatus,
                                    ),
                                  ),
                                if (role == UserRoles.provider &&
                                    status == 'accepted' &&
                                    isPaymentComplete)
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
                                      paymentStatus,
                                    ),
                                  ),
                                if (role == UserRoles.provider &&
                                    status == 'accepted' &&
                                    !isPaymentComplete)
                                  _actionChip(
                                    context: context,
                                    icon: isPaymentPending
                                        ? Icons.hourglass_bottom
                                        : Icons.payments_outlined,
                                    label: _paymentLabel(paymentStatus),
                                    color: const Color(0xFFF59E0B),
                                    onTap: () => FirestoreErrorHandler.showError(
                                      context,
                                      isPaymentPending
                                          ? 'The seeker payment is still being processed.'
                                          : 'Wait for the seeker to pay before visiting and completing this booking.',
                                    ),
                                  ),
                                if (isSeekerLike &&
                                    status == 'accepted' &&
                                    !isPaymentComplete &&
                                    !isPaymentPending)
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
                                if ((isSeekerLike && status == 'pending') ||
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
                                      paymentStatus,
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
                actions: historyActions,
                body: list,
              );
            }

            return WebPageScaffold(
              title: 'Bookings',
              subtitle: 'Track the lifecycle of your current bookings.',
              useScaffold: false,
              actions: historyActions,
              child: list,
            );
          },
        );
      },
    );
  }
}
