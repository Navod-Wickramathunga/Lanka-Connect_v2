import 'package:flutter/material.dart';
import '../ui/theme/design_tokens.dart';

/// A lightweight shimmer effect built with pure Flutter (no extra packages).
/// Wrap any placeholder layout in [ShimmerLoading] and use [ShimmerBox] for
/// individual placeholder rectangles.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          ShimmerProvider(progress: _controller.value, child: child!),
      child: widget.child,
    );
  }
}

/// Inherited widget that passes the animation progress down.
class ShimmerProvider extends InheritedWidget {
  const ShimmerProvider({
    super.key,
    required this.progress,
    required super.child,
  });

  final double progress;

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ShimmerProvider>()
            ?.progress ??
        0;
  }

  @override
  bool updateShouldNotify(ShimmerProvider oldWidget) =>
      oldWidget.progress != progress;
}

/// A single shimmer placeholder rectangle.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final progress = ShimmerProvider.of(context);
    final br = borderRadius ?? DesignTokens.radiusSm;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(br),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.0 * progress, 0),
          end: Alignment(-1.0 + 2.0 * progress + 1.0, 0),
          colors: const [
            Color(0xFFE2E8F0),
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ],
        ),
      ),
    );
  }
}

/// Pre-built shimmer placeholder for a list of card-style items.
class ShimmerCardList extends StatelessWidget {
  const ShimmerCardList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space4),
        child: Column(
          children: List.generate(itemCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space3),
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.space4),
                decoration: BoxDecoration(
                  color: DesignTokens.surface,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  border: Border.all(color: DesignTokens.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const ShimmerBox(
                          width: 48,
                          height: 48,
                          borderRadius: 24,
                        ),
                        const SizedBox(width: DesignTokens.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              ShimmerBox(height: 14),
                              SizedBox(height: DesignTokens.space2),
                              ShimmerBox(width: 120, height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.space3),
                    const ShimmerBox(height: 12),
                    const SizedBox(height: DesignTokens.space2),
                    const ShimmerBox(width: 180, height: 12),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// A grid-style shimmer placeholder for service cards.
class ShimmerServiceGrid extends StatelessWidget {
  const ShimmerServiceGrid({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space4),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: DesignTokens.space3,
            crossAxisSpacing: DesignTokens.space3,
            childAspectRatio: 0.85,
          ),
          itemCount: itemCount,
          itemBuilder: (context, _) {
            return Container(
              decoration: BoxDecoration(
                color: DesignTokens.surface,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(color: DesignTokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 100, borderRadius: DesignTokens.radiusMd),
                  Padding(
                    padding: const EdgeInsets.all(DesignTokens.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(height: 14),
                        SizedBox(height: DesignTokens.space2),
                        ShimmerBox(width: 80, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
