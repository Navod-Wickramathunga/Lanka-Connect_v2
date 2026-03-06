import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../ui/theme/design_tokens.dart';
import '../../utils/display_name_utils.dart';
import '../../utils/firestore_error_handler.dart';
import '../../utils/firestore_refs.dart';
import '../../utils/user_roles.dart';
import 'admin_banners_screen.dart';
import 'admin_promotions_screen.dart';
import 'admin_services_screen.dart';

class AdminWebDashboardScreen extends StatelessWidget {
  const AdminWebDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Column(
        children: [
          // ── Dashboard header ──
          const _DashboardHeader(),
          // ── Tabs with icons ──
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerHeight: 0,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Analytics'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 18),
                      SizedBox(width: 6),
                      Text('Users'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Moderation'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_outline, size: 18),
                      SizedBox(width: 6),
                      Text('Reviews'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.message_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Messages'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist, size: 18),
                      SizedBox(width: 6),
                      Text('Activity Log'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_carousel_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Banners'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_offer_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('Promotions'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _AnalyticsPanel(),
                _UsersPanel(),
                AdminServicesScreen(),
                _ReviewModerationPanel(),
                _MessageModerationPanel(),
                _ActivityLogPanel(),
                AdminBannersPanel(),
                AdminPromotionsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashboard header with title, subtitle, and Generate Report button.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Monitor platform performance and manage content',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report generation coming soon!')),
              );
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Generate Report'),
          ),
        ],
      ),
    );
  }
}

/// Public screen wrapping the admin users panel for bottom navigation.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UsersPanel();
  }
}

class _UsersPanel extends StatefulWidget {
  const _UsersPanel();

  @override
  State<_UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends State<_UsersPanel> {
  String _userSearch = '';
  String _roleFilter = 'all';

  Future<void> _toggleUserActive(
    BuildContext context,
    String userId,
    bool activate,
    String displayName,
  ) async {
    final action = activate ? 'activate' : 'deactivate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${activate ? 'Activate' : 'Deactivate'} User'),
        content: Text('Are you sure you want to $action "$displayName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: activate ? Colors.green : Colors.red,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(activate ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirestoreRefs.users().doc(userId).update({'isActive': activate});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${activate ? 'activated' : 'deactivated'}.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        FirestoreErrorHandler.showError(context, 'Failed to $action user: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setState(() => _userSearch = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _roleFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'provider', child: Text('Providers')),
                  DropdownMenuItem(value: 'seeker', child: Text('Seekers')),
                  DropdownMenuItem(value: 'admin', child: Text('Admins')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _roleFilter = v);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── User list ──
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreRefs.users().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load users: ${snapshot.error}'),
                );
              }

              var docs = snapshot.data?.docs ?? [];

              // Role filter
              if (_roleFilter != 'all') {
                docs = docs.where((d) {
                  final role = UserRoles.normalize(
                    d.data()['role'],
                  ).toLowerCase();
                  return role == _roleFilter;
                }).toList();
              }

              // Search filter
              if (_userSearch.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_userSearch) ||
                      email.contains(_userSearch);
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(child: Text('No users match the filters.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final role = UserRoles.normalize(data['role']);
                  final roleLabel =
                      role.substring(0, 1).toUpperCase() + role.substring(1);
                  final displayName = DisplayNameUtils.userDisplayName(
                    uid: doc.id,
                    name: data['name'],
                    email: data['email'],
                  );
                  final location = DisplayNameUtils.locationLabel(
                    city: data['city'],
                    district: data['district'],
                  );
                  final incomplete = DisplayNameUtils.isProfileIncomplete(data);
                  final isActive = data['isActive'] != false; // default true
                  final isCurrentUser =
                      doc.id == FirebaseAuth.instance.currentUser?.uid;
                  return ListTile(
                    title: Text(
                      displayName,
                      style: isActive
                          ? null
                          : const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                    ),
                    subtitle: Text(
                      'Role: $roleLabel | $location${isActive ? '' : ' | DEACTIVATED'}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        if (incomplete)
                          const Chip(label: Text('Profile incomplete')),
                        if (isCurrentUser) const Chip(label: Text('You')),
                        if (!isCurrentUser && role != UserRoles.admin)
                          IconButton(
                            icon: Icon(
                              isActive ? Icons.person_off : Icons.person_add,
                              color: isActive ? Colors.red : Colors.green,
                            ),
                            tooltip: isActive
                                ? 'Deactivate user'
                                : 'Activate user',
                            onPressed: () => _toggleUserActive(
                              context,
                              doc.id,
                              !isActive,
                              displayName,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Admin panel for review moderation - view and delete inappropriate reviews.
class _ReviewModerationPanel extends StatelessWidget {
  const _ReviewModerationPanel();

  Future<void> _deleteReview(BuildContext context, String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text(
          'Are you sure you want to delete this review? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirestoreRefs.reviews().doc(reviewId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        FirestoreErrorHandler.showError(context, 'Failed to delete review: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.reviews()
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No reviews yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final rating = (data['rating'] is num)
                ? (data['rating'] as num).toInt()
                : 0;
            final comment = (data['comment'] ?? '').toString();
            final reviewerId = (data['reviewerId'] ?? '').toString();
            final bookingId = (data['bookingId'] ?? '').toString();

            return ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              ),
              title: Text(
                comment.isNotEmpty ? comment : '(No comment)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Reviewer: ${reviewerId.length > 8 ? reviewerId.substring(0, 8) : reviewerId} | Booking: ${bookingId.length > 8 ? bookingId.substring(0, 8) : bookingId}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete review',
                onPressed: () => _deleteReview(context, doc.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stat cards 2×2 grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _StatCardEnhanced(
                      title: 'Total Revenue',
                      icon: Icons.attach_money,
                      color: DesignTokens.success,
                      stream: _MetricStreams.paymentsSuccess,
                      isCurrency: true,
                      field: 'amount',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCardEnhanced(
                      title: 'Active Users',
                      icon: Icons.people,
                      color: DesignTokens.info,
                      stream: _MetricStreams.usersTotal,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCardEnhanced(
                      title: 'Total Bookings',
                      icon: Icons.event_available,
                      color: DesignTokens.brandPrimary,
                      stream: _MetricStreams.bookingsTotal,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCardEnhanced(
                      title: 'Avg. Rating',
                      icon: Icons.star,
                      color: DesignTokens.brandSecondary,
                      stream: _MetricStreams.reviewsTotal,
                      isAverage: true,
                      field: 'rating',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Charts row ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _RevenueBarChart()),
                    const SizedBox(width: 16),
                    Expanded(child: _BookingTrendsChart()),
                  ],
                );
              }
              return Column(
                children: [
                  _RevenueBarChart(),
                  const SizedBox(height: 16),
                  _BookingTrendsChart(),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Original detailed stats ──
          Text(
            'Users & Services',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _CountCard(
                      title: 'Total Users',
                      stream: _MetricStreams.usersTotal,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _CountCard(
                      title: 'Providers',
                      stream: _MetricStreams.usersProviders,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _CountCard(
                      title: 'Seekers',
                      stream: _MetricStreams.usersSeekers,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _CountCard(
                      title: 'Pending Services',
                      stream: _MetricStreams.servicesPending,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _CountCard(
                      title: 'Approved Services',
                      stream: _MetricStreams.servicesApproved,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _CountCard(
                      title: 'Rejected Services',
                      stream: _MetricStreams.servicesRejected,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Bookings & Payments ──
          Text(
            'Bookings & Payments',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 24) / 3;
              final useWrap = constraints.maxWidth > 500;
              if (useWrap) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _CountCard(
                        title: 'Total Bookings',
                        stream: _MetricStreams.bookingsTotal,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _CountCard(
                        title: 'Payments',
                        stream: _MetricStreams.paymentsTotal,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _SumCard(
                        title: 'Revenue (LKR)',
                        stream: _MetricStreams.paymentsSuccess,
                        field: 'amount',
                      ),
                    ),
                  ],
                );
              }
              final halfWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: halfWidth,
                    child: _CountCard(
                      title: 'Total Bookings',
                      stream: _MetricStreams.bookingsTotal,
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: _CountCard(
                      title: 'Payments',
                      stream: _MetricStreams.paymentsTotal,
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: _SumCard(
                      title: 'Revenue (LKR)',
                      stream: _MetricStreams.paymentsSuccess,
                      field: 'amount',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Reviews ──
          Text(
            'Reviews',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _CountCard(
                      title: 'Total Reviews',
                      stream: _MetricStreams.reviewsTotal,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _AverageCard(
                      title: 'Avg Rating',
                      stream: _MetricStreams.reviewsTotal,
                      field: 'rating',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Pending SLA overview ──
          Text(
            'Pending SLA Overview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const _SlaSummary(),
        ],
      ),
    );
  }
}

/// Enhanced stat card with circular icon, trend badge, and formatted values.
class _StatCardEnhanced extends StatelessWidget {
  const _StatCardEnhanced({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
    this.isCurrency = false,
    this.isAverage = false,
    this.field,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isCurrency;
  final bool isAverage;
  final String? field;

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return 'LKR ${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return 'LKR ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'LKR ${value.toStringAsFixed(0)}';
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      final str = count.toString();
      final result = StringBuffer();
      for (var i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) result.write(',');
        result.write(str[i]);
      }
      return result.toString();
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DesignTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            String value = '—';
            if (snapshot.hasData) {
              final docs = snapshot.data!.docs;
              if (isCurrency && field != null) {
                double total = 0;
                for (final doc in docs) {
                  total += ((doc.data()[field!] ?? 0) as num).toDouble();
                }
                value = _formatCurrency(total);
              } else if (isAverage && field != null) {
                double sum = 0;
                int count = 0;
                for (final doc in docs) {
                  final v = doc.data()[field!];
                  if (v != null) {
                    sum += (v as num).toDouble();
                    count++;
                  }
                }
                value = count > 0 ? (sum / count).toStringAsFixed(1) : '0.0';
              } else {
                value = _formatCount(docs.length);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 22, color: color),
                    ),
                    Text(
                      '+12.5%',
                      style: TextStyle(
                        color: DesignTokens.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Revenue bar chart powered by fl_chart.
class _RevenueBarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Overview',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Monthly payment totals',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _MetricStreams.paymentsSuccess,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // Bucket payments into last 6 months
                final now = DateTime.now();
                final months = List.generate(6, (i) {
                  final dt = DateTime(now.year, now.month - (5 - i));
                  return dt;
                });

                final monthTotals = List<double>.filled(6, 0);
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data();
                  final ts = data['createdAt'] as Timestamp?;
                  if (ts == null) continue;
                  final date = ts.toDate();
                  final amount = ((data['amount'] ?? 0) as num).toDouble();
                  for (var i = 0; i < months.length; i++) {
                    if (date.year == months[i].year &&
                        date.month == months[i].month) {
                      monthTotals[i] += amount;
                      break;
                    }
                  }
                }

                final maxY = monthTotals.reduce((a, b) => a > b ? a : b);
                final topY = maxY == 0 ? 1000.0 : (maxY * 1.2).ceilToDouble();

                return SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      maxY: topY,
                      barGroups: List.generate(6, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: monthTotals[i],
                              color: DesignTokens.brandPrimary,
                              width: 22,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= months.length) {
                                return const SizedBox.shrink();
                              }
                              const labels = [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[(months[idx].month - 1) % 12],
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              final display = value >= 1000
                                  ? '${(value / 1000).toStringAsFixed(0)}k'
                                  : value.toStringAsFixed(0);
                              return Text(
                                display,
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: topY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: DesignTokens.border,
                          strokeWidth: 0.8,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              'LKR ${rod.toY.toStringAsFixed(0)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Booking trends line chart powered by fl_chart.
class _BookingTrendsChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Trends',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Monthly booking counts',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _MetricStreams.bookingsTotal,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final now = DateTime.now();
                final months = List.generate(6, (i) {
                  return DateTime(now.year, now.month - (5 - i));
                });

                final monthCounts = List<double>.filled(6, 0);
                for (final doc in snapshot.data!.docs) {
                  final ts = doc.data()['createdAt'] as Timestamp?;
                  if (ts == null) continue;
                  final date = ts.toDate();
                  for (var i = 0; i < months.length; i++) {
                    if (date.year == months[i].year &&
                        date.month == months[i].month) {
                      monthCounts[i]++;
                      break;
                    }
                  }
                }

                final maxY = monthCounts.reduce((a, b) => a > b ? a : b);
                final topY = maxY == 0 ? 10.0 : (maxY * 1.3).ceilToDouble();

                return SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      maxY: topY,
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(6, (i) {
                            return FlSpot(i.toDouble(), monthCounts[i]);
                          }),
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: DesignTokens.info,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: DesignTokens.info,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: DesignTokens.info.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= months.length) {
                                return const SizedBox.shrink();
                              }
                              const labels = [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[(months[idx].month - 1) % 12],
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: topY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: DesignTokens.border,
                          strokeWidth: 0.8,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '${spot.y.toInt()} bookings',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricStreams {
  static final usersTotal = FirestoreRefs.users().snapshots();
  static final usersProviders = FirestoreRefs.users()
      .where('role', whereIn: ['provider', 'Provider', 'Service Provider'])
      .snapshots();
  static final usersSeekers = FirestoreRefs.users()
      .where('role', isEqualTo: 'seeker')
      .snapshots();
  static final servicesPending = FirestoreRefs.services()
      .where('status', isEqualTo: 'pending')
      .snapshots();
  static final servicesApproved = FirestoreRefs.services()
      .where('status', isEqualTo: 'approved')
      .snapshots();
  static final servicesRejected = FirestoreRefs.services()
      .where('status', isEqualTo: 'rejected')
      .snapshots();
  static final bookingsTotal = FirestoreRefs.bookings().snapshots();
  static final paymentsTotal = FirestoreRefs.payments().snapshots();
  static final paymentsSuccess = FirestoreRefs.payments()
      .where('status', isEqualTo: 'success')
      .snapshots();
  static final reviewsTotal = FirestoreRefs.reviews().snapshots();
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.title, required this.stream});

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  const Text('Error'),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.data?.docs.length ?? 0}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Card that sums a numeric field across all documents.
class _SumCard extends StatelessWidget {
  const _SumCard({
    required this.title,
    required this.stream,
    required this.field,
  });

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String field;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            double total = 0;
            for (final doc in snapshot.data?.docs ?? []) {
              total += (doc.data()[field] ?? 0).toDouble();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  total.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Card that averages a numeric field across all documents.
class _AverageCard extends StatelessWidget {
  const _AverageCard({
    required this.title,
    required this.stream,
    required this.field,
  });

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String field;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            double avg = 0;
            if (docs.isNotEmpty) {
              double sum = 0;
              int count = 0;
              for (final doc in docs) {
                final v = doc.data()[field];
                if (v != null) {
                  sum += (v as num).toDouble();
                  count++;
                }
              }
              if (count > 0) avg = sum / count;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      avg.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.star, color: Colors.amber, size: 20),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shows a breakdown of pending services by SLA bucket.
class _SlaSummary extends StatelessWidget {
  const _SlaSummary();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _MetricStreams.servicesPending,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        int under12h = 0;
        int under48h = 0;
        int over48h = 0;
        final now = DateTime.now();
        for (final doc in docs) {
          final ts = doc.data()['createdAt'] as Timestamp?;
          if (ts == null) {
            over48h++;
            continue;
          }
          final hours = now.difference(ts.toDate()).inHours;
          if (hours < 12) {
            under12h++;
          } else if (hours < 48) {
            under48h++;
          } else {
            over48h++;
          }
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: (MediaQuery.of(context).size.width - 60) / 3,
              child: _slaBucket(context, '< 12 hours', under12h, Colors.green),
            ),
            SizedBox(
              width: (MediaQuery.of(context).size.width - 60) / 3,
              child: _slaBucket(
                context,
                '12-48 hours',
                under48h,
                Colors.orange,
              ),
            ),
            SizedBox(
              width: (MediaQuery.of(context).size.width - 60) / 3,
              child: _slaBucket(context, '> 48 hours', over48h, Colors.red),
            ),
          ],
        );
      },
    );
  }

  Widget _slaBucket(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin panel for message moderation - view and delete inappropriate messages.
class _MessageModerationPanel extends StatelessWidget {
  const _MessageModerationPanel();

  Future<void> _deleteMessage(BuildContext context, String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text(
          'Are you sure you want to delete this message? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirestoreRefs.messages().doc(messageId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        FirestoreErrorHandler.showError(
          context,
          'Failed to delete message: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.messages()
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No messages yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final text = (data['text'] ?? '').toString();
            final senderId = (data['senderId'] ?? '').toString();
            final chatId = (data['chatId'] ?? '').toString();
            final createdAt = data['createdAt'];
            String time = '';
            if (createdAt is Timestamp) {
              final dt = createdAt.toDate();
              time =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            }

            return ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                'Sender: ${senderId.length > 8 ? senderId.substring(0, 8) : senderId} '
                '| Chat: ${chatId.length > 8 ? chatId.substring(0, 8) : chatId}'
                '${time.isNotEmpty ? ' | $time' : ''}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete message',
                onPressed: () => _deleteMessage(context, doc.id),
              ),
            );
          },
        );
      },
    );
  }
}

/// Admin activity log - unified timeline of all seeker/provider activity.
class _ActivityLogPanel extends StatefulWidget {
  const _ActivityLogPanel();

  @override
  State<_ActivityLogPanel> createState() => _ActivityLogPanelState();
}

class _ActivityLogPanelState extends State<_ActivityLogPanel> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Activity')),
                  DropdownMenuItem(value: 'bookings', child: Text('Bookings')),
                  DropdownMenuItem(value: 'requests', child: Text('Requests')),
                  DropdownMenuItem(value: 'payments', child: Text('Payments')),
                  DropdownMenuItem(value: 'reviews', child: Text('Reviews')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _filter = v);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildActivityList()),
      ],
    );
  }

  Widget _buildActivityList() {
    // Build separate streams based on filter
    final streams = <String, Stream<QuerySnapshot<Map<String, dynamic>>>>{};

    if (_filter == 'all' || _filter == 'bookings') {
      streams['booking'] = FirestoreRefs.bookings()
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    }
    if (_filter == 'all' || _filter == 'requests') {
      streams['request'] = FirestoreRefs.requests()
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    }
    if (_filter == 'all' || _filter == 'payments') {
      streams['payment'] = FirestoreRefs.payments()
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    }
    if (_filter == 'all' || _filter == 'reviews') {
      streams['review'] = FirestoreRefs.reviews()
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    }

    // Use a StreamBuilder for each, merge results
    return StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      stream: _mergeStreams(streams.values.toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Flatten all docs with type tags
        final allEntries = <_ActivityEntry>[];
        final keys = streams.keys.toList();
        final snaps = snapshot.data ?? [];

        for (var i = 0; i < snaps.length && i < keys.length; i++) {
          final type = keys[i];
          for (final doc in snaps[i].docs) {
            final data = doc.data();
            final createdAt = data['createdAt'];
            DateTime? dt;
            if (createdAt is Timestamp) dt = createdAt.toDate();
            allEntries.add(
              _ActivityEntry(
                type: type,
                docId: doc.id,
                data: data,
                createdAt: dt,
              ),
            );
          }
        }

        // Sort by date descending
        allEntries.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(2000);
          final bTime = b.createdAt ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

        if (allEntries.isEmpty) {
          return const Center(child: Text('No activity found.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: allEntries.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = allEntries[index];
            return _buildEntryTile(context, entry);
          },
        );
      },
    );
  }

  /// Merges multiple streams into a single stream of lists.
  Stream<List<QuerySnapshot<Map<String, dynamic>>>> _mergeStreams(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams,
  ) async* {
    // Use a simpler approach: CombineLatest manually via a listener
    // For simplicity, use a recursive approach with Stream.multi
    yield* Stream<List<QuerySnapshot<Map<String, dynamic>>>>.multi((
      controller,
    ) {
      final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(
        streams.length,
        null,
      );
      var readyCount = 0;

      for (var i = 0; i < streams.length; i++) {
        streams[i].listen((snap) {
          if (latest[i] == null) readyCount++;
          latest[i] = snap;
          if (readyCount == streams.length) {
            controller.add(latest.cast<QuerySnapshot<Map<String, dynamic>>>());
          }
        }, onError: controller.addError);
      }
    });
  }

  Widget _buildEntryTile(BuildContext context, _ActivityEntry entry) {
    final data = entry.data;
    final type = entry.type;

    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (type) {
      case 'booking':
        icon = Icons.calendar_today;
        color = Colors.blue;
        final status = (data['status'] ?? 'pending').toString();
        title = 'Booking - $status';
        final seekerId = (data['seekerId'] ?? '').toString();
        final providerId = (data['providerId'] ?? '').toString();
        subtitle =
            'Seeker: ${_short(seekerId)} | Provider: ${_short(providerId)} | Amount: LKR ${data['amount'] ?? 0}';
        break;
      case 'request':
        icon = Icons.assignment;
        color = Colors.orange;
        final status = (data['status'] ?? 'pending').toString();
        title = 'Request - $status';
        final seekerId = (data['seekerId'] ?? '').toString();
        final providerId = (data['providerId'] ?? '').toString();
        subtitle =
            'Seeker: ${_short(seekerId)} | Provider: ${_short(providerId)}';
        break;
      case 'payment':
        icon = Icons.payment;
        color = Colors.green;
        final status = (data['status'] ?? '').toString();
        title = 'Payment - $status';
        final amount = data['amount'] ?? 0;
        subtitle = 'Amount: LKR $amount | Gateway: ${data['gateway'] ?? 'N/A'}';
        break;
      case 'review':
        icon = Icons.star;
        color = Colors.amber;
        final rating = data['rating'] ?? 0;
        title = 'Review - $rating/5';
        final comment = (data['comment'] ?? '').toString();
        subtitle = comment.length > 80
            ? '${comment.substring(0, 80)}...'
            : (comment.isEmpty ? '(No comment)' : comment);
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
        title = type;
        subtitle = entry.docId;
    }

    String timeStr = '';
    if (entry.createdAt != null) {
      final dt = entry.createdAt!;
      timeStr =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: timeStr.isNotEmpty
          ? Text(timeStr, style: Theme.of(context).textTheme.bodySmall)
          : null,
    );
  }

  String _short(String id) {
    if (id.isEmpty) return '-';
    return id.length > 8 ? id.substring(0, 8) : id;
  }
}

class _ActivityEntry {
  const _ActivityEntry({
    required this.type,
    required this.docId,
    required this.data,
    this.createdAt,
  });

  final String type;
  final String docId;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
}
