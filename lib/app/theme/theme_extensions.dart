import 'package:buildflow/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Text color on its own background, e.g. for a status pill.
@immutable
class ToneColors {
  const ToneColors({required this.fg, required this.bg});

  final Color fg;
  final Color bg;

  ToneColors lerpTo(ToneColors other, double t) => ToneColors(
        fg: Color.lerp(fg, other.fg, t)!,
        bg: Color.lerp(bg, other.bg, t)!,
      );
}

/// Design tokens not covered by Material 3. Read them with `context.bfTheme`.
///
/// Accent ([accent]) is for primary actions only: the main button, the active
/// navigation tab, unread badges and progress.
class BuildFlowThemeExtension extends ThemeExtension<BuildFlowThemeExtension> {
  const BuildFlowThemeExtension({
    required this.canvas,
    required this.card,
    required this.border,
    required this.muted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.graphite,
    required this.onGraphite,
    required this.onGraphiteSecondary,
    required this.active,
    required this.paused,
    required this.danger,
    required this.finished,
    required this.avatars,
    required this.photoPlaceholders,
  });

  /// Screen background.
  final Color canvas;
  final Color card;

  /// 1px card, nav bar and icon button border.
  final Color border;

  /// Progress track, chips, inputs.
  final Color muted;
  final Color textPrimary;
  final Color textSecondary;

  /// Times and captions.
  final Color textTertiary;
  final Color accent;
  final Color onAccent;

  /// Accent used as a text or link color.
  final Color accentText;

  /// Dark summary card, secondary button, active filter chip.
  final Color graphite;
  final Color onGraphite;
  final Color onGraphiteSecondary;

  /// Status tones: in progress / report sent.
  final ToneColors active;
  final ToneColors paused;

  /// Errors and "no report today".
  final ToneColors danger;
  final ToneColors finished;

  /// Pastel avatar backgrounds; pick with [avatarFor].
  final List<ToneColors> avatars;
  final List<Color> photoPlaceholders;

  // ── Shapes ──────────────────────────────────────────────────
  static const double cardRadius = 20;
  static const double buttonRadius = 16;
  static const double inputRadius = 14;
  static const double iconButtonRadius = 14;
  static const double photoRadius = 12;
  static const double bottomSheetRadius = 24;

  /// Graphite scrim under the text on a cover photo; with it white and
  /// [onGraphiteSecondary] text pass 4.5:1 even over a white photo.
  static const double coverScrimOpacity = 0.9;

  /// Stable avatar colors for a name.
  ToneColors avatarFor(String seed) {
    // String.hashCode is not stable across runs; this sum is.
    final code = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return avatars[code % avatars.length];
  }

  static final light = BuildFlowThemeExtension(
    canvas: AppColors.canvasLight,
    card: AppColors.cardLight,
    border: AppColors.borderLight,
    muted: AppColors.mutedLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    textTertiary: AppColors.textTertiaryLight,
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    accentText: AppColors.accentTextLight,
    graphite: AppColors.graphiteLight,
    onGraphite: AppColors.onGraphite,
    onGraphiteSecondary: AppColors.onGraphiteSecondary,
    active: const ToneColors(
      fg: AppColors.activeFgLight,
      bg: AppColors.activeBgLight,
    ),
    paused: const ToneColors(
      fg: AppColors.pausedFgLight,
      bg: AppColors.pausedBgLight,
    ),
    danger: const ToneColors(
      fg: AppColors.dangerFgLight,
      bg: AppColors.dangerBgLight,
    ),
    finished: const ToneColors(
      fg: AppColors.finishedFgLight,
      bg: AppColors.finishedBgLight,
    ),
    avatars: [
      for (final a in AppColors.avatarsLight) ToneColors(fg: a.fg, bg: a.bg),
    ],
    photoPlaceholders: AppColors.photoPlaceholders,
  );

  static final dark = BuildFlowThemeExtension(
    canvas: AppColors.canvasDark,
    card: AppColors.cardDark,
    border: AppColors.borderDark,
    muted: AppColors.mutedDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    accentText: AppColors.accentTextDark,
    graphite: AppColors.graphiteDark,
    onGraphite: AppColors.onGraphite,
    onGraphiteSecondary: AppColors.onGraphiteSecondary,
    active: const ToneColors(
      fg: AppColors.activeFgDark,
      bg: AppColors.activeBgDark,
    ),
    paused: const ToneColors(
      fg: AppColors.pausedFgDark,
      bg: AppColors.pausedBgDark,
    ),
    danger: const ToneColors(
      fg: AppColors.dangerFgDark,
      bg: AppColors.dangerBgDark,
    ),
    finished: const ToneColors(
      fg: AppColors.finishedFgDark,
      bg: AppColors.finishedBgDark,
    ),
    avatars: [
      for (final a in AppColors.avatarsDark) ToneColors(fg: a.fg, bg: a.bg),
    ],
    photoPlaceholders: AppColors.photoPlaceholders,
  );

  @override
  BuildFlowThemeExtension copyWith({
    Color? canvas,
    Color? card,
    Color? border,
    Color? muted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? graphite,
    Color? onGraphite,
    Color? onGraphiteSecondary,
    ToneColors? active,
    ToneColors? paused,
    ToneColors? danger,
    ToneColors? finished,
    List<ToneColors>? avatars,
    List<Color>? photoPlaceholders,
  }) {
    return BuildFlowThemeExtension(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentText: accentText ?? this.accentText,
      graphite: graphite ?? this.graphite,
      onGraphite: onGraphite ?? this.onGraphite,
      onGraphiteSecondary: onGraphiteSecondary ?? this.onGraphiteSecondary,
      active: active ?? this.active,
      paused: paused ?? this.paused,
      danger: danger ?? this.danger,
      finished: finished ?? this.finished,
      avatars: avatars ?? this.avatars,
      photoPlaceholders: photoPlaceholders ?? this.photoPlaceholders,
    );
  }

  @override
  BuildFlowThemeExtension lerp(
    covariant BuildFlowThemeExtension? other,
    double t,
  ) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return BuildFlowThemeExtension(
      canvas: c(canvas, other.canvas),
      card: c(card, other.card),
      border: c(border, other.border),
      muted: c(muted, other.muted),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      accentText: c(accentText, other.accentText),
      graphite: c(graphite, other.graphite),
      onGraphite: c(onGraphite, other.onGraphite),
      onGraphiteSecondary: c(onGraphiteSecondary, other.onGraphiteSecondary),
      active: active.lerpTo(other.active, t),
      paused: paused.lerpTo(other.paused, t),
      danger: danger.lerpTo(other.danger, t),
      finished: finished.lerpTo(other.finished, t),
      // Lists switch halfway, like Material's own discrete tokens.
      avatars: t < 0.5 ? avatars : other.avatars,
      photoPlaceholders: t < 0.5 ? photoPlaceholders : other.photoPlaceholders,
    );
  }
}

/// Extension for convenient access from BuildContext.
extension BuildFlowThemeX on BuildContext {
  BuildFlowThemeExtension get bfTheme =>
      Theme.of(this).extension<BuildFlowThemeExtension>()!;
}
