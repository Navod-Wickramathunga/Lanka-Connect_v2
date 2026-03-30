import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../ui/mobile/mobile_tokens.dart';
import '../utils/banner_image_defaults.dart';
import '../utils/firestore_refs.dart';

DateTime? _parseOptionalDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

/// Data for a single banner slide.
class BannerData {
  const BannerData({
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.color,
    this.imageUrl,
    this.fallbackImageUrl,
    this.scheduledStart,
    this.scheduledEnd,
  });
  final String title;
  final String subtitle;
  final String ctaText;
  final Color color;
  final String? imageUrl;
  final String? fallbackImageUrl;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  /// Whether this banner should be visible right now based on its schedule.
  bool get isWithinSchedule {
    final now = DateTime.now();
    if (scheduledStart != null && now.isBefore(scheduledStart!)) return false;
    if (scheduledEnd != null && now.isAfter(scheduledEnd!)) return false;
    return true;
  }

  /// Create from Firestore document data.
  factory BannerData.fromMap(Map<String, dynamic> data) {
    const fallbackColor = Color(0xFF2563EB);
    Color color;
    try {
      final hex = (data['colorHex'] ?? '')
          .toString()
          .replaceAll('#', '')
          .trim();
      if (hex.length == 6) {
        color = Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        color = Color(int.parse(hex, radix: 16));
      } else {
        color = fallbackColor;
      }
    } catch (_) {
      color = fallbackColor;
    }
    final title = (data['title'] ?? '').toString();
    final subtitle = (data['subtitle'] ?? '').toString();
    final ctaText = (data['ctaText'] ?? 'Learn More').toString();
    final rawUrl = (data['imageUrl'] ?? '').toString().trim();
    final fallbackImageUrl = defaultBannerImageUrl(
      title: title,
      subtitle: subtitle,
      ctaText: ctaText,
    );
    return BannerData(
      title: title,
      subtitle: subtitle,
      ctaText: ctaText,
      color: color,
      imageUrl: rawUrl.isEmpty ? null : rawUrl,
      fallbackImageUrl: fallbackImageUrl,
      scheduledStart: _parseOptionalDate(data['scheduledStart']),
      scheduledEnd: _parseOptionalDate(data['scheduledEnd']),
    );
  }
}

/// Auto-scrolling banner carousel matching the React BannerCarousel design.
/// Reads active banners from the `banners` Firestore collection.
/// Falls back to hardcoded defaults if no Firestore data exists.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, this.onCtaTap});

  final void Function(BannerData banner)? onCtaTap;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  /// Hardcoded defaults used when no Firestore banners exist.
  static const _defaultBanners = [
    BannerData(
      title: 'Spring Cleaning Sale',
      subtitle: 'Get 20% off all deep cleaning services this week!',
      ctaText: 'Book Now',
      color: Color(0xFF2563EB),
      imageUrl:
          'https://images.pexels.com/photos/6197116/pexels-photo-6197116.jpeg',
      fallbackImageUrl:
          'https://images.pexels.com/photos/14675103/pexels-photo-14675103.jpeg',
    ),
    BannerData(
      title: 'Emergency Plumbing?',
      subtitle: 'Expert plumbers available 24/7 in your area.',
      ctaText: 'Find Help',
      color: Color(0xFF0891B2),
      imageUrl:
          'https://images.pexels.com/photos/7859953/pexels-photo-7859953.jpeg',
      fallbackImageUrl:
          'https://images.pexels.com/photos/7859953/pexels-photo-7859953.jpeg',
    ),
    BannerData(
      title: 'Join as a Pro',
      subtitle: 'Expand your business and reach more customers.',
      ctaText: 'Register',
      color: Color(0xFF0D9488),
      imageUrl:
          'https://images.pexels.com/photos/8487997/pexels-photo-8487997.jpeg',
      fallbackImageUrl:
          'https://images.pexels.com/photos/13821194/pexels-photo-13821194.jpeg',
    ),
  ];

  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 0;
  int _bannerCount = _defaultBanners.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _bannerCount == 0) return;
      final next = (_currentPage + 1) % _bannerCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreRefs.banners()
          .where('active', isEqualTo: true)
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        // Build banner list: Firestore docs if available, else defaults
        final List<BannerData> banners;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final remoteBanners = <BannerData>[];
          for (final doc in snapshot.data!.docs) {
            try {
              remoteBanners.add(BannerData.fromMap(doc.data()));
            } catch (_) {
              // Skip malformed docs; keep carousel usable.
            }
          }

          banners = remoteBanners.where((b) => b.isWithinSchedule).toList();
          if (banners.isEmpty) {
            banners.addAll(_defaultBanners);
          }
        } else {
          banners = _defaultBanners;
        }
        _bannerCount = banners.length;

        return Column(
          children: [
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: banners.length,
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return _BannerSlide(
                    banner: banner,
                    onCtaTap: () => widget.onCtaTap?.call(banner),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isActive
                        ? MobileTokens.primary
                        : MobileTokens.border,
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner, this.onCtaTap});

  final BannerData banner;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MobileTokens.radiusXl),
        gradient: LinearGradient(
          colors: [banner.color, banner.color.withValues(alpha: 0.7)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: banner.color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MobileTokens.radiusXl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BannerImageLayer(banner: banner),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    banner.color.withValues(alpha: 0.82),
                    banner.color.withValues(alpha: 0.56),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'FEATURED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    banner.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: onCtaTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      icon: Text(banner.ctaText),
                      label: const Icon(Icons.arrow_forward, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerImageLayer extends StatelessWidget {
  const _BannerImageLayer({required this.banner});

  final BannerData banner;

  @override
  Widget build(BuildContext context) {
    final primaryUrl = banner.imageUrl?.trim() ?? '';

    if (primaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: primaryUrl,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => _fallbackImage(),
      );
    }

    return _fallbackImage();
  }

  Widget _fallbackImage() {
    final fallbackUrl = banner.fallbackImageUrl?.trim() ?? '';
    if (fallbackUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: fallbackUrl,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }
}
