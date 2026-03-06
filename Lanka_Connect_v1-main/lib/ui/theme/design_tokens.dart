import 'package:flutter/material.dart';

/// Central design token source used by both mobile and web UI layers.
/// Replace values with Figma-exported tokens during later visual iterations.
class DesignTokens {
  const DesignTokens._();

  // Semantic colors
  static const Color brandPrimary = Color(0xFF0D9488);
  static const Color brandSecondary = Color(0xFFF59E0B);
  static const Color accent = Color(0xFF14B8A6);
  static const Color brandInk = Color(0xFF0F172A);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color surfaceElevated = Color(0xFFF1F5F9);
  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF020617);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textSubtle = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  static const List<Color> authGradient = [
    Color(0xFF0F766E),
    Color(0xFF0F172A),
  ];

  // Web auth revamp tokens (warm trust direction)
  static const List<Color> authWebBackgroundGradient = [
    Color(0xFFF7F4EE),
    Color(0xFFE8EEF6),
  ];
  static const List<Color> authWebHeroGradient = [
    Color(0xFF0B5D57),
    Color(0xFF143B58),
  ];
  static const Color authWebHeroGlow = Color(0x3329B7A7);
  static const Color authWebHeroText = Color(0xFFF4FBFA);
  static const Color authWebHeroTextMuted = Color(0xFFD5ECE8);
  static const Color authWebHeroAccent = Color(0xFFFFD58A);
  static const Color authWebPanelSurface = Color(0xFFFAFCFF);
  static const Color authWebPanelBorder = Color(0xFFDDE5F0);
  static const Color authWebPanelShadow = Color(0x1A0F2238);
  static const Color authWebPanelMuted = Color(0xFF5D7285);
  static const Color authWebPanelTitle = Color(0xFF102235);
  static const Color authWebPrimaryAction = Color(0xFF0F766E);
  static const Color authWebPrimaryActionHover = Color(0xFF0C615A);
  static const Color authWebPrimaryActionPressed = Color(0xFF0A4F4A);
  static const Color authWebAccentWarm = Color(0xFFF59E0B);
  static const Color authWebWarmSurface = Color(0xFFFFF7E7);
  static const Color authWebWarmText = Color(0xFF7A4B00);
  static const Color authWebChipBorder = Color(0xFFD2DEEA);
  static const Color authWebChipFill = Color(0xFFFFFFFF);
  static const Color authWebChipHover = Color(0xFFF2F7FB);
  static const Color authWebChipSelectedBorder = Color(0xFF138076);
  static const Color authWebChipSelectedFill = Color(0xFFE7F8F5);
  static const Color authWebChipLabel = Color(0xFF1E3245);
  static const Color authWebChipSelectedLabel = Color(0xFF0F5C54);
  static const Color authWebSecondaryActionSurface = Color(0xFFE7EFF7);
  static const Color authWebSecondaryActionHover = Color(0xFFDCE7F1);
  static const Color authWebSecondaryActionText = Color(0xFF18354D);
  static const Color authWebErrorSurface = Color(0xFFFFF1F2);
  static const Color authWebErrorBorder = Color(0xFFF5C2C7);
  static const Color authWebSuccessText = Color(0xFF047857);
  static const double authWebHeroRadius = 32;
  static const double authWebPanelRadius = 30;
  static const double authWebDialogRadius = 24;
  static const double authWebPanelShadowBlur = 30;

  static const List<Color> mobileHeaderGradient = [
    Color(0xFF0D9488),
    Color(0xFF0F766E),
  ];

  // Spacing scale
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;

  // Radius scale
  static const double radiusSm = 10;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;

  // Elevation
  static const double elevation0 = 0;
  static const double elevation1 = 1;
  static const double elevation2 = 3;
  static const double elevation3 = 8;
}

class AppTypeScale {
  const AppTypeScale._();

  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.3,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
}
