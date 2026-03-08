import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../utils/firestore_refs.dart';

/// Data for a single promotion card.
class PromotionData {
  const PromotionData({
    required this.title,
    required this.description,
    required this.discount,
    required this.expiry,
    required this.color,
    required this.icon,
    this.linkedCategory,
    this.scheduledStart,
    this.scheduledEnd,
  });
  final String title;
  final String description;
  final String discount;
  final String expiry;
  final Color color;
  final IconData icon;
  final String? linkedCategory;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  /// Whether this promotion is currently within its schedule window.
  bool get isWithinSchedule {
    final now = DateTime.now();
    if (scheduledStart != null && now.isBefore(scheduledStart!)) return false;
    if (scheduledEnd != null && now.isAfter(scheduledEnd!)) return false;
    return true;
  }

  /// Map of icon names to IconData for Firestore-driven icons.
  static const _iconMap = <String, IconData>{
    'cleaning_services': Icons.cleaning_services,
    'plumbing': Icons.plumbing,
    'electrical_services': Icons.electrical_services,
    'carpenter': Icons.carpenter,
    'format_paint': Icons.format_paint,
    'grass': Icons.grass,
    'local_shipping': Icons.local_shipping,
    'spa': Icons.spa,
    'school': Icons.school,
    'ac_unit': Icons.ac_unit,
    'yard': Icons.yard,
    'handyman': Icons.handyman,
    'home_repair_service': Icons.home_repair_service,
    'local_offer': Icons.local_offer,
    'star': Icons.star,
  };

  /// Create from Firestore document data.
  factory PromotionData.fromMap(Map<String, dynamic> data) {
    Color color;
    try {
      final hex = (data['colorHex'] ?? '').toString().replaceAll('#', '');
      color = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      color = const Color(0xFFF43F5E);
    }
    final iconName = (data['iconName'] ?? 'local_offer').toString();
    return PromotionData(
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      discount: (data['discount'] ?? '').toString(),
      expiry: (data['expiry'] ?? 'Limited Time').toString(),
      color: color,
      icon: _iconMap[iconName] ?? Icons.local_offer,
      linkedCategory: (data['linkedCategory'] ?? '').toString(),
      scheduledStart: data['scheduledStart'] != null
          ? (data['scheduledStart'] as Timestamp).toDate()
          : null,
      scheduledEnd: data['scheduledEnd'] != null
          ? (data['scheduledEnd'] as Timestamp).toDate()
          : null,
    );
  }
}

/// Exclusive offers section matching the React PromotionSection design.
/// Reads active promotions from the `promotions` Firestore collection.
/// Falls back to hardcoded defaults if no documents exist.
class PromotionSection extends StatelessWidget {
  const PromotionSection({super.key, this.onViewAll, this.onPromoTap});

  final VoidCallback? onViewAll;

  /// Called when a promotion card is tapped, with the linked category name.
  final void Function(String category)? onPromoTap;

  static const _defaultPromotions = [
    PromotionData(
      title: 'Weekend Cleaner',
      description: 'Get your house sparkling clean for the weekend.',
      discount: '15% OFF',
      expiry: 'Ends Sunday',
      color: Color(0xFFF43F5E),
      icon: Icons.cleaning_services,
      linkedCategory: 'Cleaning',
    ),
    PromotionData(
      title: 'AC Service',
      description: 'Beat the heat with a full AC checkup.',
      discount: 'Rs. 500 OFF',
      expiry: 'Limited Time',
      color: Color(0xFF3B82F6),
      icon: Icons.ac_unit,
      linkedCategory: 'Electrical',
    ),
    PromotionData(
      title: 'Garden Makeover',
      description: 'Revamp your outdoor space this season.',
      discount: 'Free Quote',
      expiry: 'Valid 24h',
      color: Color(0xFF22C55E),
      icon: Icons.yard,
      linkedCategory: 'Gardening',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.promotions()
          .where('active', isEqualTo: true)
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        final List<PromotionData> promotions;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          promotions = snapshot.data!.docs
              .map((d) => PromotionData.fromMap(d.data()))
              .where((p) => p.isWithinSchedule)
              .toList();
        } else {
          promotions = _defaultPromotions;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_offer,
                      color: isDark
                          ? const Color(0xFFFDA4AF)
                          : const Color(0xFFF43F5E),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Exclusive Offers',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onViewAll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            color: MobileTokens.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: MobileTokens.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Promotion cards
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: promotions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final promo = promotions[index];
                  return _PromotionCard(
                    promo: promo,
                    onTap: onPromoTap != null
                        ? () => onPromoTap!(promo.linkedCategory ?? '')
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({required this.promo, this.onTap});

  final PromotionData promo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(MobileTokens.radiusLg),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left icon/color section
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: promo.color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(promo.icon, color: promo.color, size: 36),
              ),
            ),
            // Content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: promo.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        promo.discount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      promo.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      promo.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          promo.expiry,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: MobileTokens.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
