import 'package:flutter/material.dart';
import 'web_tokens.dart';

class WebShellNavItem {
  const WebShellNavItem({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

class WebShell extends StatelessWidget {
  const WebShell({
    super.key,
    required this.appTitle,
    required this.navItems,
    required this.currentId,
    required this.onSelect,
    required this.pageTitle,
    this.pageSubtitle,
    this.actions = const [],
    required this.child,
  });

  final String appTitle;
  final List<WebShellNavItem> navItems;
  final String currentId;
  final ValueChanged<String> onSelect;
  final String pageTitle;
  final String? pageSubtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navigator = Navigator.maybeOf(context);
    final rootNavigator = Navigator.maybeOf(context, rootNavigator: true);
    final canShowBack =
        (navigator?.canPop() ?? false) || (rootNavigator?.canPop() ?? false);
    return Scaffold(
      backgroundColor: isDark ? WebTokens.backgroundDark : WebTokens.background,
      body: SafeArea(
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 980;
                  return Row(
                    children: [
                      _Sidebar(
                        appTitle: appTitle,
                        compact: compact,
                        items: navItems,
                        currentId: currentId,
                        onSelect: onSelect,
                        isDark: isDark,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 82,
                              margin: const EdgeInsets.all(WebTokens.spacingMd),
                              padding: const EdgeInsets.symmetric(
                                horizontal: WebTokens.spacingLg,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0B1220)
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(
                                  WebTokens.radiusXl,
                                ),
                                border: Border.all(color: theme.dividerColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? const Color(0x44000000)
                                        : const Color(0x14000000),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  if (canShowBack) ...[
                                    IconButton(
                                      onPressed: () async {
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
                                        backgroundColor: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        foregroundColor:
                                            theme.colorScheme.primary,
                                      ),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: WebTokens.spacingSm),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          pageTitle,
                                          style: WebTypography.sectionTitle(
                                            context,
                                          ),
                                        ),
                                        if (pageSubtitle != null)
                                          Text(
                                            pageSubtitle!,
                                            style: WebTypography.pageSubtitle(
                                              context,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    spacing: WebTokens.spacingSm,
                                    children: actions,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.appTitle,
    required this.compact,
    required this.items,
    required this.currentId,
    required this.onSelect,
    this.isDark = false,
  });

  final String appTitle;
  final bool compact;
  final List<WebShellNavItem> items;
  final String currentId;
  final ValueChanged<String> onSelect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final sidebarBg = isDark ? const Color(0xFF020617) : WebTokens.brandDark;
    return Container(
      width: compact ? 86 : 250,
      margin: const EdgeInsets.fromLTRB(
        WebTokens.spacingMd,
        WebTokens.spacingMd,
        0,
        WebTokens.spacingMd,
      ),
      padding: const EdgeInsets.all(WebTokens.spacingMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sidebarBg, sidebarBg.withValues(alpha: 0.92)],
        ),
        borderRadius: BorderRadius.circular(WebTokens.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Icon(Icons.public, color: Colors.white, size: compact ? 26 : 24),
          if (!compact) ...[
            const SizedBox(height: WebTokens.spacingSm),
            Text(
              appTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Service Marketplace',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: WebTokens.spacingLg),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: WebTokens.spacingXs),
              child: _SidebarItem(
                item: item,
                compact: compact,
                selected: item.id == currentId,
                onTap: () => onSelect(item.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final WebShellNavItem item;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WebTokens.radiusMd),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        scale: selected ? 1.02 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? WebTokens.spacingXs : WebTokens.spacingSm,
            vertical: WebTokens.spacingSm,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF134E4A) : Colors.transparent,
            borderRadius: BorderRadius.circular(WebTokens.radiusMd),
            border: selected
                ? Border.all(color: const Color(0xFF5EEAD4))
                : Border.all(color: Colors.transparent),
          ),
          child: compact
              ? AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: selected ? 0.015 : 0,
                  child: Icon(item.icon, color: Colors.white),
                )
              : Row(
                  children: [
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 220),
                      turns: selected ? 0.015 : 0,
                      child: Icon(item.icon, color: Colors.white),
                    ),
                    const SizedBox(width: WebTokens.spacingSm),
                    Expanded(
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        offset: selected ? const Offset(0.03, 0) : Offset.zero,
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
