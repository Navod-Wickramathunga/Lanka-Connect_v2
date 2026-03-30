import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/mobile/mobile_components.dart';
import '../../ui/mobile/mobile_page_scaffold.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../../ui/theme/design_tokens.dart';
import '../../ui/web/web_page_scaffold.dart';
import '../../utils/app_feedback.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import 'payment_screen.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  static const _dateFormat = 'dd MMM yyyy, hh:mm a';

  bool _isPaid(String status) => status == 'paid' || status == 'success';

  bool _isPending(String status) =>
      status == 'initiated' ||
      status == 'pending_gateway' ||
      status == 'pending_verification';

  String _shortId(String id, {int length = 8}) {
    final value = id.trim();
    if (value.isEmpty) return 'Unknown';
    final take = value.length < length ? value.length : length;
    return value.substring(0, take);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
      case 'success':
        return 'Paid';
      case 'pending_gateway':
        return 'Pending gateway';
      case 'pending_verification':
        return 'Pending verification';
      case 'initiated':
        return 'Initiated';
      case 'failed':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  String _methodLabel(Map<String, dynamic> data) {
    final methodType = (data['methodType'] ?? '').toString().trim();
    switch (methodType) {
      case 'saved_card':
        final summary = data['paymentMethodSummary'];
        if (summary is Map<String, dynamic>) {
          final brand = (summary['brand'] ?? '').toString().trim();
          final last4 = (summary['last4'] ?? '').toString().trim();
          final details = [
            brand,
            if (last4.isNotEmpty) '****$last4',
          ].where((value) => value.isNotEmpty).join(' ');
          if (details.isNotEmpty) return details;
        }
        return 'Saved card';
      case 'bank_transfer':
        return 'Bank transfer';
      case 'card':
        return 'Card';
      default:
        final gateway = (data['gateway'] ?? '').toString().trim();
        return gateway.isNotEmpty ? gateway.replaceAll('_', ' ') : 'Payment';
    }
  }

  double _amountOf(Map<String, dynamic> data) {
    final netAmount = data['netAmount'];
    if (netAmount is num) return netAmount.toDouble();
    final amount = data['amount'];
    return amount is num ? amount.toDouble() : 0;
  }

  Timestamp? _createdAtOf(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return createdAt is Timestamp ? createdAt : null;
  }

  Color _statusColor(String status) {
    if (_isPaid(status)) return const Color(0xFF15803D);
    if (_isPending(status)) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  IconData _statusIcon(String status) {
    if (_isPaid(status)) return Icons.check_circle_outline;
    if (_isPending(status)) return Icons.pending_outlined;
    return Icons.cancel_outlined;
  }

  String _summaryText(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var totalPaid = 0.0;
    var totalPending = 0.0;
    var failedCount = 0;

    for (final doc in docs) {
      final data = doc.data();
      final amount = _amountOf(data);
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (_isPaid(status)) {
        totalPaid += amount;
      } else if (_isPending(status)) {
        totalPending += amount;
      } else {
        failedCount++;
      }
    }

    final lines = <String>[
      'Lanka Connect payment history',
      'Total attempts: ${docs.length}',
      'Paid total: LKR ${totalPaid.toStringAsFixed(2)}',
      'Pending total: LKR ${totalPending.toStringAsFixed(2)}',
      'Failed attempts: $failedCount',
      '',
      'Recent payments:',
    ];

    for (final doc in docs.take(10)) {
      final data = doc.data();
      final amount = _amountOf(data);
      final status = _statusLabel((data['status'] ?? '').toString().trim());
      final method = _methodLabel(data);
      final bookingId = (data['bookingId'] ?? '').toString().trim();
      final createdAt = _createdAtOf(data);
      final when = createdAt == null
          ? 'Date unavailable'
          : DateFormat(_dateFormat).format(createdAt.toDate().toLocal());
      lines.add(
        '- Booking ${_shortId(bookingId)} | LKR ${amount.toStringAsFixed(2)} | $method | $status | $when',
      );
    }

    return lines.join('\n');
  }

  Future<void> _copySummary(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final summary = _summaryText(docs);
    await Clipboard.setData(ClipboardData(text: summary));
    if (!context.mounted) return;
    TigerFeedback.show(
      context,
      'Payment history copied to clipboard.',
      tone: TigerFeedbackTone.success,
    );
  }

  Future<void> _emailSummary(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Lanka Connect payment history',
        'body': _summaryText(docs),
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {
      // Fallback to clipboard below when an email client is unavailable.
    }

    await Clipboard.setData(ClipboardData(text: _summaryText(docs)));
    if (!context.mounted) return;
    TigerFeedback.show(
      context,
      'No email app was available, so the history was copied instead.',
      tone: TigerFeedbackTone.info,
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var totalPaid = 0.0;
    var pendingTotal = 0.0;
    var failedCount = 0;

    for (final doc in docs) {
      final data = doc.data();
      final amount = _amountOf(data);
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (_isPaid(status)) {
        totalPaid += amount;
      } else if (_isPending(status)) {
        pendingTotal += amount;
      } else {
        failedCount++;
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your payment details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'See every payment attempt and send a compact history summary.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricPill(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Paid total',
                  value: 'LKR ${totalPaid.toStringAsFixed(2)}',
                  color: const Color(0xFF15803D),
                ),
                _MetricPill(
                  icon: Icons.hourglass_bottom_outlined,
                  label: 'Pending',
                  value: 'LKR ${pendingTotal.toStringAsFixed(2)}',
                  color: const Color(0xFFD97706),
                ),
                _MetricPill(
                  icon: Icons.receipt_long_outlined,
                  label: 'Attempts',
                  value: '${docs.length}',
                  color: DesignTokens.brandPrimary,
                ),
                _MetricPill(
                  icon: Icons.error_outline,
                  label: 'Failed',
                  value: '$failedCount',
                  color: const Color(0xFFDC2626),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _copySummary(context, docs),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copy summary'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _emailSummary(context, docs),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send by email'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        final status = (data['status'] ?? '').toString().trim().toLowerCase();
        final bookingId = (data['bookingId'] ?? '').toString().trim();
        final amount = _amountOf(data);
        final createdAt = _createdAtOf(data);
        final transactionId =
            ((data['gatewayRefs'] as Map?)?['transactionId'] ?? '')
                .toString()
                .trim();
        final color = _statusColor(status);
        final when = createdAt == null
            ? 'Date unavailable'
            : DateFormat(_dateFormat).format(createdAt.toDate().toLocal());

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: color.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_statusIcon(status), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking ${_shortId(bookingId)}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            when,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DetailChip(
                      icon: Icons.payments_outlined,
                      label: 'Amount',
                      value: 'LKR ${amount.toStringAsFixed(2)}',
                    ),
                    _DetailChip(
                      icon: Icons.credit_card_outlined,
                      label: 'Method',
                      value: _methodLabel(data),
                    ),
                    if (transactionId.isNotEmpty)
                      _DetailChip(
                        icon: Icons.confirmation_number_outlined,
                        label: 'Transaction',
                        value: transactionId,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: bookingId.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PaymentScreen(bookingId: bookingId),
                              ),
                            ),
                      icon: const Icon(Icons.open_in_new_outlined),
                      label: const Text('Open booking payment'),
                    ),
                    TextButton.icon(
                      onPressed: transactionId.isEmpty
                          ? () => _copySummary(context, [doc])
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: transactionId),
                              );
                              if (!context.mounted) return;
                              TigerFeedback.show(
                                context,
                                'Transaction ID copied.',
                                tone: TigerFeedbackTone.success,
                              );
                            },
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(
                        transactionId.isEmpty
                            ? 'Copy payment line'
                            : 'Copy transaction ID',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kIsWeb) {
        return const WebPageScaffold(
          title: 'Payment History',
          subtitle: 'Review and send your payment details.',
          useScaffold: true,
          child: Center(child: Text('Not signed in')),
        );
      }
      return const MobilePageScaffold(
        title: 'Payment History',
        subtitle: 'Review and send your payment details.',
        accentColor: MobileTokens.primary,
        useScaffold: true,
        body: Center(child: Text('Not signed in')),
      );
    }

    final body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.payments()
          .where('seekerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
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

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          final empty = const MobileEmptyState(
            title: 'No payment history yet.',
            subtitle:
                'Completed, pending, and failed payment attempts will appear here.',
            icon: Icons.receipt_long_outlined,
          );
          if (kIsWeb) {
            return const WebStatePanel(
              icon: Icons.receipt_long_outlined,
              title: 'No payment history yet.',
              subtitle:
                  'Completed, pending, and failed payment attempts will appear here.',
            );
          }
          return empty;
        }

        return Column(
          children: [
            _buildOverviewCard(context, docs),
            const SizedBox(height: 12),
            Expanded(child: _buildHistoryList(context, docs)),
          ],
        );
      },
    );

    if (kIsWeb) {
      return WebPageScaffold(
        title: 'Payment History',
        subtitle: 'Review and send your payment details.',
        useScaffold: true,
        child: Padding(padding: const EdgeInsets.all(20), child: body),
      );
    }

    return MobilePageScaffold(
      title: 'Payment History',
      subtitle: 'Review and send your payment details.',
      accentColor: MobileTokens.primary,
      useScaffold: true,
      body: body,
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: DesignTokens.brandPrimary),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
