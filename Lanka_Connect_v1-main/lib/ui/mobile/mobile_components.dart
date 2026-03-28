import 'package:flutter/material.dart';
import 'mobile_tokens.dart';

class MobileGradientHeader extends StatelessWidget {
  const MobileGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.accentColor,
    this.showBackButton = false,
    this.onBackPressed,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color accentColor;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 360 ? 22.0 : (width < 420 ? 24.0 : 26.0);
    final subtitleSize = width < 360 ? 12.0 : 13.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MobileTokens.spacingLg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MobileTokens.radiusXl),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  accentColor.withValues(alpha: 0.8),
                  MobileTokens.backgroundDark,
                ]
              : [accentColor, MobileTokens.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            Builder(
              builder: (context) {
                final navigator = Navigator.maybeOf(context);
                final rootNavigator = Navigator.maybeOf(
                  context,
                  rootNavigator: true,
                );
                return IconButton(
                  onPressed:
                      onBackPressed ??
                      () async {
                        if (navigator != null && await navigator.maybePop()) {
                          return;
                        }
                        if (rootNavigator != null &&
                            rootNavigator != navigator) {
                          await rootNavigator.maybePop();
                        }
                      },
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  tooltip: 'Back',
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: titleSize,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: const Color(0xFFE9F3FF),
                      fontSize: subtitleSize,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class MobileSectionCard extends StatelessWidget {
  const MobileSectionCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(MobileTokens.spacingLg),
        child: child,
      ),
    );
  }
}

class MobilePageIntro extends StatelessWidget {
  const MobilePageIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MobileTokens.spacingMd,
        MobileTokens.spacingXs,
        MobileTokens.spacingMd,
        MobileTokens.spacingMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(153),
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: MobileTokens.spacingSm),
            action!,
          ],
        ],
      ),
    );
  }
}

class MobileStatusChip extends StatelessWidget {
  const MobileStatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class MobileEmptyState extends StatelessWidget {
  const MobileEmptyState({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.action,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return MobileStatePanel(
      icon: icon,
      title: title,
      subtitle: subtitle,
      tone: MobileStateTone.muted,
      action: action,
    );
  }
}

enum MobileStateTone { muted, info, error }

class MobileStatePanel extends StatelessWidget {
  const MobileStatePanel({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = MobileStateTone.muted,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final MobileStateTone tone;
  final Widget? action;

  Color _toneColor() {
    switch (tone) {
      case MobileStateTone.info:
        return MobileTokens.primary;
      case MobileStateTone.error:
        return Colors.red;
      case MobileStateTone.muted:
        return MobileTokens.inkMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _toneColor();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MobileTokens.spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: MobileTokens.inkMuted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
