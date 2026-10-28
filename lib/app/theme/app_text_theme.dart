import 'package:flutter/material.dart';

/// Typography scale using Inter (full Cyrillic support).
///
/// - headlineLarge 30/w800 — screen title
/// - headlineMedium 26/w800 — project header
/// - titleLarge 20/w700 — app bar title on pushed screens, sheets, dialogs
/// - titleMedium 17/w700 — card title
/// - bodyLarge / bodyMedium 15 — body text
/// - bodySmall 13 — captions, times
/// - labelLarge 15/w700 — text buttons; [button] 17/w800 — main buttons
abstract final class AppTextTheme {
  /// Bundled in assets/fonts/inter, weights 400–800 (see pubspec.yaml).
  static const fontFamily = 'Inter';

  /// Numbers that line up in columns: counters, times, percents.
  static const tabular = [FontFeature.tabularFigures()];

  /// Label of BfButton and other full-width action buttons.
  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  // The family is set on every style, not only in ThemeData: the app bar and
  // buttons take their styles straight from this theme.
  static TextTheme get textTheme {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.72,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.64,
        height: 1.1,
      ),
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.56,
        height: 1.15,
      ),
      // −0.02em letter spacing on the large headings.
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.52,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.44,
        height: 1.25,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    ).apply(fontFamily: fontFamily);
  }
}
