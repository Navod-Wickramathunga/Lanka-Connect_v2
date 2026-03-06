import 'package:flutter/material.dart';
import 'mobile_components.dart';
import 'mobile_tokens.dart';

class MobilePageScaffold extends StatelessWidget {
  const MobilePageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor = MobileTokens.primary,
    required this.body,
    this.actions = const [],
    this.useScaffold = false,
    this.showBackButton,
    this.onBackPressed,
  });

  final String title;
  final String? subtitle;
  final Color accentColor;
  final Widget body;
  final List<Widget> actions;
  final bool useScaffold;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final shouldShowBack = showBackButton ?? Navigator.of(context).canPop();
    final content = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(MobileTokens.spacingMd),
            child: MobileGradientHeader(
              title: title,
              subtitle: subtitle,
              accentColor: accentColor,
              showBackButton: shouldShowBack,
              onBackPressed: onBackPressed,
              trailing: actions.isEmpty
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MobileTokens.spacingMd,
                0,
                MobileTokens.spacingMd,
                MobileTokens.spacingMd,
              ),
              child: body,
            ),
          ),
        ],
      ),
    );

    if (!useScaffold) return content;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: content,
    );
  }
}
