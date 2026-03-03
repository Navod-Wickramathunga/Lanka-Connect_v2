import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_tokens.dart';

/// Data for a single promotion card.
class PromotionData {
  const PromotionData({
    required this.title,
    required this.description,
    required this.discount,
    required this.expiry,
    required this.color,
    required this.icon,
  });
  final String title;
  final String description;
  final String discount;
  final String expiry;
  final Color color;
  final IconData icon;
}

/// Exclusive offers section matching the React PromotionSection design.
class PromotionSection extends StatelessWidget {
  const PromotionSection({super.key, this.onViewAll, this.onPromoTap});

  final VoidCallback? onViewAll;
  final void Function(int index)? onPromoTap;

  static const _promotions = [
    PromotionData(
      title: 'Weekend Cleaner',
      description: 'Get your house sparkling clean for the weekend.',
      discount: '15% OFF',
      expiry: 'Ends Sunday',
      color: Color(0xFFF43F5E),
      icon: Icons.cleaning_services,
    ),
    PromotionData(
      title: 'AC Service',
      description: 'Beat the heat with a full AC checkup.',
      discount: 'Rs. 500 OFF',
      expiry: 'Limited Time',
      color: Color(0xFF3B82F6),
      icon: Icons.ac_unit,
    ),
    PromotionData(
      title: 'Garden Makeover',
      description: 'Revamp your outdoor space this season.',
      discount: 'Free Quote',
      expiry: 'Valid 24h',
      color: Color(0xFF22C55E),
      icon: Icons.yard,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
            itemCount: _promotions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _PromotionCard(
                promo: _promotions[index],
                onTap: onPromoTap != null ? () => onPromoTap!(index) : null,
              );
            },
          ),
        ),
      ],
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
