import 'package:flutter/material.dart';
import '../ui/theme/design_tokens.dart';
import 'animated_icon.dart';

/// Data model for a service category in the category bar.
class CategoryItem {
  const CategoryItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.background,
    this.animation = IconAnimation.scale,
  });

  final String name;
  final IconData icon;
  final Color color;
  final Color background;
  final IconAnimation animation;
}

/// Horizontal scrollable category icon bar matching the React SeekerHome
/// CATEGORIES array. Supports selection callback and animated icons.
class CategoryBar extends StatelessWidget {
  const CategoryBar({super.key, this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  static const List<CategoryItem> categories = [
    CategoryItem(
      name: 'Cleaning',
      icon: Icons.cleaning_services,
      color: Color(0xFF0D9488),
      background: Color(0xFFCCFBF1),
      animation: IconAnimation.bounce,
    ),
    CategoryItem(
      name: 'Plumbing',
      icon: Icons.plumbing,
      color: Color(0xFF2563EB),
      background: Color(0xFFDBEAFE),
      animation: IconAnimation.wiggle,
    ),
    CategoryItem(
      name: 'Electrical',
      icon: Icons.electrical_services,
      color: Color(0xFFD97706),
      background: Color(0xFFFEF3C7),
      animation: IconAnimation.pulse,
    ),
    CategoryItem(
      name: 'Carpentry',
      icon: Icons.carpenter,
      color: Color(0xFF92400E),
      background: Color(0xFFFDE68A),
      animation: IconAnimation.rotate,
    ),
    CategoryItem(
      name: 'Painting',
      icon: Icons.format_paint,
      color: Color(0xFF7C3AED),
      background: Color(0xFFEDE9FE),
      animation: IconAnimation.scale,
    ),
    CategoryItem(
      name: 'Gardening',
      icon: Icons.grass,
      color: Color(0xFF059669),
      background: Color(0xFFD1FAE5),
      animation: IconAnimation.bounce,
    ),
    CategoryItem(
      name: 'Moving',
      icon: Icons.local_shipping,
      color: Color(0xFFDC2626),
      background: Color(0xFFFEE2E2),
      animation: IconAnimation.shake,
    ),
    CategoryItem(
      name: 'Beauty',
      icon: Icons.spa,
      color: Color(0xFFDB2777),
      background: Color(0xFFFCE7F3),
      animation: IconAnimation.pulse,
    ),
    CategoryItem(
      name: 'Tutoring',
      icon: Icons.school,
      color: Color(0xFF4F46E5),
      background: Color(0xFFE0E7FF),
      animation: IconAnimation.scale,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildCategoryItem(CategoryItem cat) {
      final isSelected = selected?.toLowerCase() == cat.name.toLowerCase();
      final bgColor = isDark
          ? cat.color.withValues(alpha: 0.2)
          : cat.background;
      final borderColor = isSelected ? cat.color : Colors.transparent;
      return GestureDetector(
        onTap: () => onSelected(isSelected ? '' : cat.name),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 2.5 : 0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: cat.color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: AnimatedIconWidget(
                  icon: cat.icon,
                  size: 28,
                  color: cat.color,
                  animation: cat.animation,
                  isActive: isSelected,
                  triggerOnTap: false,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? cat.color
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Browse Categories',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (selected != null && selected!.isNotEmpty)
                TextButton(
                  onPressed: () => onSelected(''),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // On wide screens (web), use centered wrap layout
            if (constraints.maxWidth >= 700) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: categories.map(buildCategoryItem).toList(),
                ),
              );
            }
            // On mobile, keep horizontal scroll
            return SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    buildCategoryItem(categories[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}
