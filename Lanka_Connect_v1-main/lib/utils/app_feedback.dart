import 'package:flutter/material.dart';

enum TigerFeedbackTone { info, success, warning, error }

class TigerFeedback {
  const TigerFeedback._();

  static void show(
    BuildContext context,
    String message, {
    TigerFeedbackTone tone = TigerFeedbackTone.info,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final theme = Theme.of(context);
    final palette = _paletteForTone(tone, theme.colorScheme);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: palette.background,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: palette.border),
          ),
          content: Row(
            children: [
              Icon(palette.icon, color: palette.foreground, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static _TigerFeedbackPalette _paletteForTone(
    TigerFeedbackTone tone,
    ColorScheme scheme,
  ) {
    switch (tone) {
      case TigerFeedbackTone.success:
        return _TigerFeedbackPalette(
          background: const Color(0xFFECFDF5),
          foreground: const Color(0xFF047857),
          border: const Color(0xFFA7F3D0),
          icon: Icons.pets,
        );
      case TigerFeedbackTone.warning:
        return _TigerFeedbackPalette(
          background: const Color(0xFFFFFBEB),
          foreground: const Color(0xFFB45309),
          border: const Color(0xFFFCD34D),
          icon: Icons.pets,
        );
      case TigerFeedbackTone.error:
        return _TigerFeedbackPalette(
          background: const Color(0xFFFEF2F2),
          foreground: const Color(0xFFB91C1C),
          border: const Color(0xFFFECACA),
          icon: Icons.pets,
        );
      case TigerFeedbackTone.info:
        return _TigerFeedbackPalette(
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurface,
          border: scheme.outlineVariant,
          icon: Icons.pets,
        );
    }
  }
}

class _TigerFeedbackPalette {
  const _TigerFeedbackPalette({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;
}
