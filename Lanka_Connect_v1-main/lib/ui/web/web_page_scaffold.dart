import 'package:flutter/material.dart';
import 'web_tokens.dart';

class WebPageScaffold extends StatelessWidget {
  const WebPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.useScaffold = false,
    this.showBackButton,
    this.onBackPressed,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool useScaffold;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navigator = Navigator.maybeOf(context);
    final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
    final shouldShowBack =
        showBackButton ??
        (navigator?.canPop() ?? false) || (rootNavigator?.canPop() ?? false);
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF020617), Color(0xFF0F172A)]
                  : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(WebTokens.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: WebTokens.spacingSm,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shouldShowBack) ...[
                          IconButton(
                            onPressed:
                                onBackPressed ??
                                () async {
                                  if (navigator != null &&
                                      await navigator.maybePop()) {
                                    return;
                                  }
                                  if (rootNavigator != null &&
                                      rootNavigator != navigator) {
                                    await rootNavigator.maybePop();
                                  }
                                },
                            tooltip: 'Back',
                            style: IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.surface,
                              foregroundColor: theme.colorScheme.primary,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: WebTokens.spacingSm),
                        ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: WebTypography.pageTitle(context),
                            ),
                            if (subtitle != null &&
                                subtitle!.trim().isNotEmpty) ...[
                              const SizedBox(height: WebTokens.spacingXs),
                              Text(
                                subtitle!,
                                style: WebTypography.pageSubtitle(context),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (actions.isNotEmpty)
                      Wrap(spacing: WebTokens.spacingSm, children: actions),
                  ],
                ),
                const SizedBox(height: WebTokens.spacingMd),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0B1220)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(WebTokens.radiusXl),
                      border: Border.all(color: theme.dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x44000000)
                              : const Color(0x14000000),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!useScaffold) return content;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(child: content),
    );
  }
}

enum WebStateTone { muted, info, error }

class WebStatePanel extends StatelessWidget {
  const WebStatePanel({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.tone = WebStateTone.muted,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final WebStateTone tone;

  Color _toneColor() {
    switch (tone) {
      case WebStateTone.info:
        return WebTokens.brand;
      case WebStateTone.error:
        return Colors.red;
      case WebStateTone.muted:
        return WebTokens.inkSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _toneColor();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WebTokens.spacingLg),
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
                style: const TextStyle(color: WebTokens.inkSecondary),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
