import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../ui/theme/design_tokens.dart';
import '../../utils/firestore_refs.dart';

/// Provider dashboard summary screen showing monthly stats,
/// earning overview, ratings, and level progression.
class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not signed in'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return RefreshIndicator(
      color: DesignTokens.brandPrimary,
      onRefresh: () async {
        // Trigger rebuild
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Greeting ──
          _ProviderGreeting(uid: uid),
          const SizedBox(height: 20),

          // ── Quick Stats Row ──
          _QuickStatsRow(uid: uid, cardColor: cardColor),
          const SizedBox(height: 20),

          // ── Monthly Service Summary ──
          _SectionHeader(
            title: 'Monthly Service Summary',
            icon: Icons.bar_chart,
          ),
          const SizedBox(height: 8),
          _MonthlyServiceSummary(uid: uid, cardColor: cardColor),
          const SizedBox(height: 20),

          // ── Payment Details ──
          _SectionHeader(title: 'Payment Overview', icon: Icons.payments),
          const SizedBox(height: 8),
          _PaymentOverview(uid: uid, cardColor: cardColor),
          const SizedBox(height: 20),

          // ── Ratings & Reviews ──
          _SectionHeader(title: 'Ratings & Reviews', icon: Icons.star),
          const SizedBox(height: 8),
          _RatingsCard(uid: uid, cardColor: cardColor),
          const SizedBox(height: 20),

          // ── Level & Incentives ──
          _SectionHeader(title: 'Level & Incentives', icon: Icons.emoji_events),
          const SizedBox(height: 8),
          _LevelCard(uid: uid, cardColor: cardColor),
          const SizedBox(height: 20),

          // ── Recent Tasks ──
          _SectionHeader(title: 'Recent Bookings', icon: Icons.task_alt),
          const SizedBox(height: 8),
          _RecentBookings(uid: uid, cardColor: cardColor),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: DesignTokens.brandPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Greeting
// ─────────────────────────────────────────────────────────────────────────────

class _ProviderGreeting extends StatelessWidget {
  const _ProviderGreeting({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.users().doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final name = (data['name'] ?? 'Provider').toString();
        final firstName = name.split(' ').first;
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good Morning'
            : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                DesignTokens.brandPrimary,
                DesignTokens.brandPrimary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Here\'s your dashboard summary',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Stats Row
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.uid, required this.cardColor});
  final String uid;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatMini(
            label: 'Services',
            icon: Icons.store,
            color: const Color(0xFF3B82F6),
            stream: FirestoreRefs.services()
                .where('providerId', isEqualTo: uid)
                .snapshots(),
            cardColor: cardColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMini(
            label: 'Bookings',
            icon: Icons.calendar_today,
            color: const Color(0xFF22C55E),
            stream: FirestoreRefs.bookings()
                .where('providerId', isEqualTo: uid)
                .snapshots(),
            cardColor: cardColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMini(
            label: 'Reviews',
            icon: Icons.rate_review,
            color: const Color(0xFFF59E0B),
            stream: FirestoreRefs.reviews()
                .where('providerId', isEqualTo: uid)
                .snapshots(),
            cardColor: cardColor,
          ),
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
    required this.cardColor,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Card(
          color: cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly Service Summary
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyServiceSummary extends StatelessWidget {
  const _MonthlyServiceSummary({required this.uid, required this.cardColor});
  final String uid;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.bookings()
          .where('providerId', isEqualTo: uid)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int completed = 0;
        int pending = 0;
        int cancelled = 0;
        for (final doc in docs) {
          final status = (doc.data()['status'] ?? '').toString().toLowerCase();
          if (status == 'completed' || status == 'done') {
            completed++;
          } else if (status == 'cancelled' || status == 'canceled') {
            cancelled++;
          } else {
            pending++;
          }
        }

        return Card(
          color: cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MonthStat(
                      label: 'Total',
                      value: '${docs.length}',
                      color: DesignTokens.brandPrimary,
                    ),
                    const SizedBox(width: 16),
                    _MonthStat(
                      label: 'Completed',
                      value: '$completed',
                      color: const Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 16),
                    _MonthStat(
                      label: 'Pending',
                      value: '$pending',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 16),
                    _MonthStat(
                      label: 'Cancelled',
                      value: '$cancelled',
                      color: const Color(0xFFEF4444),
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
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Overview
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentOverview extends StatelessWidget {
  const _PaymentOverview({required this.uid, required this.cardColor});
  final String uid;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.payments()
          .where('providerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        double totalEarnings = 0;
        double pendingPayments = 0;
        int successCount = 0;

        for (final doc in docs) {
          final data = doc.data();
          final amount = (data['amount'] is num)
              ? (data['amount'] as num).toDouble()
              : 0.0;
          final status = (data['status'] ?? '').toString().toLowerCase();
          if (status == 'success' ||
              status == 'completed' ||
              status == 'paid') {
            totalEarnings += amount;
            successCount++;
          } else if (status == 'pending') {
            pendingPayments += amount;
          }
        }

        return Card(
          color: cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _PaymentRow(
                  icon: Icons.account_balance_wallet,
                  label: 'Total Earnings',
                  value: 'LKR ${totalEarnings.toStringAsFixed(2)}',
                  color: const Color(0xFF22C55E),
                ),
                const Divider(height: 20),
                _PaymentRow(
                  icon: Icons.pending_actions,
                  label: 'Pending',
                  value: 'LKR ${pendingPayments.toStringAsFixed(2)}',
                  color: const Color(0xFFF59E0B),
                ),
                const Divider(height: 20),
                _PaymentRow(
                  icon: Icons.receipt_long,
                  label: 'Transactions',
                  value: '$successCount completed',
                  color: DesignTokens.brandPrimary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ratings & Reviews
// ─────────────────────────────────────────────────────────────────────────────

class _RatingsCard extends StatelessWidget {
  const _RatingsCard({required this.uid, required this.cardColor});
  final String uid;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.reviews()
          .where('providerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        double avgRating = 0;
        final starCounts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

        if (docs.isNotEmpty) {
          double sum = 0;
          for (final doc in docs) {
            final r = (doc.data()['rating'] is num)
                ? (doc.data()['rating'] as num).toDouble()
                : 0.0;
            sum += r;
            final bucket = r.round().clamp(1, 5);
            starCounts[bucket] = (starCounts[bucket] ?? 0) + 1;
          }
          avgRating = sum / docs.length;
        }

        return Card(
          color: cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Average rating section
                Column(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DesignTokens.brandPrimary,
                          ),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < avgRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${docs.length} reviews',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Star breakdown
                Expanded(
                  child: Column(
                    children: [5, 4, 3, 2, 1].map((star) {
                      final count = starCounts[star] ?? 0;
                      final pct = docs.isEmpty ? 0.0 : count / docs.length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text(
                              '$star',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.withValues(
                                    alpha: 0.2,
                                  ),
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.amber.shade600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level & Incentives
// ─────────────────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.uid, required this.cardColor});
  final String uid;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    // Derive level from completed bookings count
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.bookings()
          .where('providerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        final completedCount = snapshot.data?.docs.length ?? 0;
        final level = _computeLevel(completedCount);

        return Card(
          color: cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: level.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(level.icon, color: level.color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: level.color,
                                ),
                          ),
                          Text(
                            '$completedCount completed jobs',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress to next level
                if (level.nextThreshold != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress to ${level.nextName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$completedCount / ${level.nextThreshold}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completedCount / level.nextThreshold!,
                      minHeight: 8,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(level.color),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Incentive info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: level.color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: level.color.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard, size: 18, color: level.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          level.incentive,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: level.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static _LevelInfo _computeLevel(int completedJobs) {
    if (completedJobs >= 100) {
      return _LevelInfo(
        name: 'Platinum',
        icon: Icons.diamond,
        color: const Color(0xFF6366F1),
        incentive: 'Priority listing + 0% commission + Featured badge',
        nextName: null,
        nextThreshold: null,
      );
    } else if (completedJobs >= 50) {
      return _LevelInfo(
        name: 'Gold',
        icon: Icons.workspace_premium,
        color: const Color(0xFFF59E0B),
        incentive: 'Featured in top results + 5% reduced commission',
        nextName: 'Platinum',
        nextThreshold: 100,
      );
    } else if (completedJobs >= 20) {
      return _LevelInfo(
        name: 'Silver',
        icon: Icons.military_tech,
        color: const Color(0xFF64748B),
        incentive: 'Profile badge + 10% commission discount',
        nextName: 'Gold',
        nextThreshold: 50,
      );
    } else {
      return _LevelInfo(
        name: 'Bronze',
        icon: Icons.shield,
        color: const Color(0xFFCD7F32),
        incentive: 'Complete 20 jobs to unlock Silver benefits',
        nextName: 'Silver',
        nextThreshold: 20,
      );
    }
  }
}

class _LevelInfo {
  const _LevelInfo({
    required this.name,
    required this.icon,
    required this.color,
    required this.incentive,
    required this.nextName,
    required this.nextThreshold,
  });
  final String name;
  final IconData icon;
  final Color color;
  final String incentive;
  final String? nextName;
  final int? nextThreshold;
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Bookings
// ─────────────────────────────────────────────────────────────────────────────

class _RecentBookings extends StatelessWidget {
  const _RecentBookings({required this.uid, required this.cardColor});
  final String uid;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.bookings()
          .where('providerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Card(
            color: cardColor,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No bookings yet')),
            ),
          );
        }

        return Card(
          color: cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: docs.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value.data();
              final title = (data['serviceTitle'] ?? data['title'] ?? 'Service')
                  .toString();
              final status = (data['status'] ?? 'pending').toString();
              final ts = data['createdAt'];
              String dateStr = '';
              if (ts is Timestamp) {
                final dt = ts.toDate();
                dateStr = '${dt.day}/${dt.month}/${dt.year}';
              }

              Color statusColor;
              switch (status.toLowerCase()) {
                case 'completed':
                case 'done':
                  statusColor = const Color(0xFF22C55E);
                  break;
                case 'cancelled':
                case 'canceled':
                  statusColor = const Color(0xFFEF4444);
                  break;
                default:
                  statusColor = const Color(0xFFF59E0B);
              }

              return Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.handyman, size: 18, color: statusColor),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (index < docs.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
