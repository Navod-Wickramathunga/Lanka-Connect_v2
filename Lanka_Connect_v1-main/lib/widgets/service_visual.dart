import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ServiceVisualStyle {
  const ServiceVisualStyle({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.icon,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final IconData icon;
}

ServiceVisualStyle serviceVisualStyleForCategory(String category) {
  switch (category.trim().toLowerCase()) {
    case 'cleaning':
      return const ServiceVisualStyle(
        primary: Color(0xFF0F766E),
        secondary: Color(0xFF5EEAD4),
        accent: Color(0xFFCCFBF1),
        icon: Icons.cleaning_services,
      );
    case 'plumbing':
      return const ServiceVisualStyle(
        primary: Color(0xFF1D4ED8),
        secondary: Color(0xFF60A5FA),
        accent: Color(0xFFDBEAFE),
        icon: Icons.plumbing,
      );
    case 'electrical':
      return const ServiceVisualStyle(
        primary: Color(0xFFB45309),
        secondary: Color(0xFFF59E0B),
        accent: Color(0xFFFEF3C7),
        icon: Icons.electrical_services,
      );
    case 'carpentry':
      return const ServiceVisualStyle(
        primary: Color(0xFF92400E),
        secondary: Color(0xFFD97706),
        accent: Color(0xFFFEF3C7),
        icon: Icons.carpenter,
      );
    case 'painting':
      return const ServiceVisualStyle(
        primary: Color(0xFF7C3AED),
        secondary: Color(0xFFA78BFA),
        accent: Color(0xFFEDE9FE),
        icon: Icons.format_paint,
      );
    case 'gardening':
      return const ServiceVisualStyle(
        primary: Color(0xFF15803D),
        secondary: Color(0xFF4ADE80),
        accent: Color(0xFFDCFCE7),
        icon: Icons.grass,
      );
    case 'moving':
      return const ServiceVisualStyle(
        primary: Color(0xFFB91C1C),
        secondary: Color(0xFFFB7185),
        accent: Color(0xFFFFE4E6),
        icon: Icons.local_shipping,
      );
    case 'beauty':
      return const ServiceVisualStyle(
        primary: Color(0xFFBE185D),
        secondary: Color(0xFFF472B6),
        accent: Color(0xFFFCE7F3),
        icon: Icons.spa,
      );
    case 'tutoring':
      return const ServiceVisualStyle(
        primary: Color(0xFF4338CA),
        secondary: Color(0xFF818CF8),
        accent: Color(0xFFE0E7FF),
        icon: Icons.school,
      );
    default:
      return const ServiceVisualStyle(
        primary: Color(0xFF0F766E),
        secondary: Color(0xFF38BDF8),
        accent: Color(0xFFE0F2FE),
        icon: Icons.home_repair_service,
      );
  }
}

class ServiceVisual extends StatelessWidget {
  const ServiceVisual({
    super.key,
    required this.title,
    required this.category,
    this.imageUrl,
    this.height = 160,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.showOverlay = false,
  });

  final String title;
  final String category;
  final String? imageUrl;
  final double height;
  final double width;
  final BorderRadius borderRadius;
  final bool showOverlay;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl?.trim() ?? '';
    final child = trimmedUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: trimmedUrl,
            height: height,
            width: width,
            fit: BoxFit.cover,
            placeholder: (context, url) => _fallback(context),
            errorWidget: (context, url, error) => _fallback(context),
          )
        : _fallback(context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [child, if (showOverlay) _overlay(context)],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final style = serviceVisualStyleForCategory(category);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.primary, style.secondary],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -height * 0.18,
            right: -width * 0.12,
            child: _orb(
              size: height * 0.62,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            left: -height * 0.08,
            bottom: -height * 0.16,
            child: _orb(
              size: height * 0.5,
              color: style.accent.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 18,
            bottom: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  style.icon,
                  size: height * 0.34,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
          if (!showOverlay)
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.62)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _categoryBadge(),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryBadge() {
    final style = serviceVisualStyleForCategory(category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            category.trim().isEmpty ? 'Service' : category,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb({required double size, required Color color}) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
