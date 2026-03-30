import 'package:flutter/material.dart';
import '../ui/theme/design_tokens.dart';
import 'service_visual.dart';

/// An enhanced service card matching the React ServiceCard component.
/// Features: hero image, rating stars, review count, price badge, location,
/// category chip, and animated hover elevation.
class ServiceCardEnhanced extends StatefulWidget {
  const ServiceCardEnhanced({
    super.key,
    required this.title,
    required this.category,
    required this.price,
    this.imageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.location,
    this.distance,
    this.status,
    this.onTap,
  });

  final String title;
  final String category;
  final double price;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final String? location;
  final String? distance;
  final String? status;
  final VoidCallback? onTap;

  @override
  State<ServiceCardEnhanced> createState() => _ServiceCardEnhancedState();
}

class _ServiceCardEnhancedState extends State<ServiceCardEnhanced> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visualStyle = serviceVisualStyleForCategory(widget.category);
    final catColor = visualStyle.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _hovering
            ? (Matrix4.identity()..setTranslationRaw(0, -2, 0))
            : Matrix4.identity(),
        child: Card(
          elevation: _hovering ? 6 : 2,
          shadowColor: isDark
              ? Colors.black54
              : catColor.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image section
                _buildImage(),
                // Content section
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category chip
                      _buildCategoryChip(catColor, visualStyle.icon, isDark),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Rating row
                      if (widget.rating > 0 || widget.reviewCount > 0)
                        _buildRatingRow(),
                      if (widget.rating > 0 || widget.reviewCount > 0)
                        const SizedBox(height: 6),
                      // Location
                      if (widget.location != null &&
                          widget.location!.isNotEmpty)
                        _buildLocation(),
                      const SizedBox(height: 8),
                      // Price & distance
                      _buildPriceRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Stack(
      children: [
        ServiceVisual(
          title: widget.title,
          category: widget.category,
          imageUrl: widget.imageUrl,
          height: 160,
          borderRadius: BorderRadius.zero,
        ),
        if (widget.status != null)
          Positioned(top: 8, right: 8, child: _statusBadge(widget.status!)),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    switch (status.toLowerCase()) {
      case 'approved':
        bg = DesignTokens.success;
        break;
      case 'rejected':
        bg = DesignTokens.danger;
        break;
      case 'pending':
        bg = DesignTokens.warning;
        break;
      default:
        bg = DesignTokens.info;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    Color catColor,
    IconData categoryIcon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? catColor.withValues(alpha: 0.2)
            : catColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon, size: 14, color: catColor),
          const SizedBox(width: 4),
          Text(
            widget.category,
            style: TextStyle(
              color: catColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        ..._starIcons(widget.rating),
        const SizedBox(width: 4),
        Text(
          widget.rating.toStringAsFixed(1),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${widget.reviewCount})',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }

  List<Widget> _starIcons(double rating) {
    final stars = <Widget>[];
    for (var i = 1; i <= 5; i++) {
      if (rating >= i) {
        stars.add(const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)));
      } else if (rating >= i - 0.5) {
        stars.add(
          const Icon(Icons.star_half, size: 14, color: Color(0xFFF59E0B)),
        );
      } else {
        stars.add(
          Icon(
            Icons.star_border,
            size: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        );
      }
    }
    return stars;
  }

  Widget _buildLocation() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.location_on, size: 14, color: muted),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            widget.location!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: DesignTokens.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'LKR ${widget.price.toStringAsFixed(0)}',
            style: const TextStyle(
              color: DesignTokens.brandPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        if (widget.distance != null)
          Row(
            children: [
              Icon(Icons.near_me, size: 14, color: muted),
              const SizedBox(width: 2),
              Text(
                widget.distance!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
