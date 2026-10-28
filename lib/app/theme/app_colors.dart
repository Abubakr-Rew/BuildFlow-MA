import 'package:flutter/material.dart';

/// Raw palette: graphite, stone background and signal orange.
///
/// Screens never use these directly — they go through the theme
/// (`Theme.of(context).colorScheme` or `context.bfTheme`). Every text/background
/// pair here is checked for ≥ 4.5:1 in test/app/theme/contrast_test.dart.
abstract final class AppColors {
  // ── Accent: signal orange, the same in both themes ─────────
  static const accent = Color(0xFFFF6B1A);

  /// Text on [accent]. White fails contrast on this orange.
  static const onAccent = Color(0xFF15171A);

  // ── Light ───────────────────────────────────────────────────
  static const canvasLight = Color(0xFFF3F2EE);
  static const cardLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE4E2DC);
  static const mutedLight = Color(0xFFEEECE7);
  static const textPrimaryLight = Color(0xFF15171A);
  static const textSecondaryLight = Color(0xFF5B5F66);
  static const textTertiaryLight = Color(0xFF666A72);
  static const accentTextLight = Color(0xFFB84A0C);
  static const graphiteLight = Color(0xFF1B1E22);
  static const onGraphite = Color(0xFFFFFFFF);
  static const onGraphiteSecondary = Color(0xFFB9BDC4);

  static const activeFgLight = Color(0xFF1E6B3E);
  static const activeBgLight = Color(0xFFE3F2E8);
  static const pausedFgLight = Color(0xFF6B4600);
  static const pausedBgLight = Color(0xFFFBEFD5);
  static const dangerFgLight = Color(0xFF9B1C14);
  static const dangerBgLight = Color(0xFFFBE4E1);
  static const finishedFgLight = Color(0xFF1D3F73);
  static const finishedBgLight = Color(0xFFD6E2F5);

  // ── Dark ────────────────────────────────────────────────────
  static const canvasDark = Color(0xFF121417);
  static const cardDark = Color(0xFF1B1E22);
  static const borderDark = Color(0xFF2E333A);
  static const mutedDark = Color(0xFF262A30);
  static const textPrimaryDark = Color(0xFFF2F1ED);
  static const textSecondaryDark = Color(0xFFA9AEB6);
  static const textTertiaryDark = Color(0xFF8E939B);
  static const accentTextDark = Color(0xFFFF9A5C);
  static const graphiteDark = Color(0xFF2A2F36);

  static const activeFgDark = Color(0xFF7FD49B);
  static const activeBgDark = Color(0xFF16301F);
  static const pausedFgDark = Color(0xFFF2C46B);
  static const pausedBgDark = Color(0xFF33270D);
  static const dangerFgDark = Color(0xFFFF9C92);
  static const dangerBgDark = Color(0xFF3A1714);
  static const finishedFgDark = Color(0xFF9DBDF0);
  static const finishedBgDark = Color(0xFF172540);

  // ── Avatars: pastel background + dark ink of the same hue ───
  static const avatarsLight = [
    (bg: Color(0xFFFFE1CC), fg: Color(0xFF7A3208)),
    (bg: Color(0xFFD9E8FB), fg: Color(0xFF1D3F73)),
    (bg: Color(0xFFDDF0E2), fg: Color(0xFF1E5B36)),
    (bg: Color(0xFFF1DDF4), fg: Color(0xFF5E2669)),
    (bg: Color(0xFFFBEFC8), fg: Color(0xFF5E4300)),
    (bg: Color(0xFFDDEFF0), fg: Color(0xFF1F5458)),
  ];
  static const avatarsDark = [
    (bg: Color(0xFF4A2A16), fg: Color(0xFFFFC9A3)),
    (bg: Color(0xFF1E3150), fg: Color(0xFFB9D2F5)),
    (bg: Color(0xFF1E3A28), fg: Color(0xFFAEE2BE)),
    (bg: Color(0xFF3B2441), fg: Color(0xFFE6C3EE)),
    (bg: Color(0xFF3D3214), fg: Color(0xFFF4DB94)),
    (bg: Color(0xFF1D393B), fg: Color(0xFFADE0E3)),
  ];

  // ── Demo photo placeholders (`fake:` urls) ──────────────────
  static const photoPlaceholders = [
    Color(0xFF5B5F66),
    Color(0xFF6D5A4B),
    Color(0xFF4F5B66),
    Color(0xFF7A5F48),
    Color(0xFF3F464E),
    Color(0xFF8A6A50),
    Color(0xFF2E3338),
    Color(0xFF66574C),
  ];
}
