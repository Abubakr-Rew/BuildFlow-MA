import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Material 3 theme: graphite, stone background, signal orange.
///
/// The Material [ColorScheme] is derived from [BuildFlowThemeExtension], so
/// dialogs, menus and snack bars match the custom components.
abstract final class AppTheme {
  // ── 4pt spacing grid ────────────────────────────────────────
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing48 = 48;

  /// Left and right padding of every screen.
  static const double screenPadding = 20;

  /// Gap between cards in a list.
  static const double cardGap = 12;

  // ── Touch targets ──────────────────────────────────────────
  static const double minTouchTarget = 48;
  static const double iconButtonSize = 44;
  static const double primaryActionHeight = 56;

  // ── Themes ──────────────────────────────────────────────────
  static ThemeData get light =>
      _buildTheme(BuildFlowThemeExtension.light, Brightness.light);

  static ThemeData get dark =>
      _buildTheme(BuildFlowThemeExtension.dark, Brightness.dark);

  static ColorScheme _colorScheme(BuildFlowThemeExtension t, Brightness b) {
    final isLight = b == Brightness.light;
    // The first avatar tone is the orange one.
    final accentTint = t.avatars.first;
    return ColorScheme(
      brightness: b,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: accentTint.bg,
      onPrimaryContainer: accentTint.fg,
      secondary: t.graphite,
      onSecondary: t.onGraphite,
      secondaryContainer: t.muted,
      onSecondaryContainer: t.textPrimary,
      tertiary: t.finished.fg,
      onTertiary: t.finished.bg,
      tertiaryContainer: t.finished.bg,
      onTertiaryContainer: t.finished.fg,
      error: t.danger.fg,
      onError: isLight ? t.card : t.onAccent,
      errorContainer: t.danger.bg,
      onErrorContainer: t.danger.fg,
      surface: t.canvas,
      onSurface: t.textPrimary,
      onSurfaceVariant: t.textSecondary,
      surfaceContainerLowest: t.card,
      surfaceContainerLow: t.card,
      surfaceContainer: t.card,
      surfaceContainerHigh: t.muted,
      surfaceContainerHighest: t.muted,
      outline: t.textTertiary,
      outlineVariant: t.border,
      inverseSurface: t.graphite,
      onInverseSurface: t.onGraphite,
      inversePrimary: t.accent,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static ThemeData _buildTheme(BuildFlowThemeExtension t, Brightness b) {
    final colorScheme = _colorScheme(t, b);
    final textTheme = AppTextTheme.textTheme.apply(
      bodyColor: t.textPrimary,
      displayColor: t.textPrimary,
    );
    OutlineInputBorder inputBorder([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(BuildFlowThemeExtension.inputRadius),
          borderSide: side,
        );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BuildFlowThemeExtension.buttonRadius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: colorScheme,
      fontFamily: AppTextTheme.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: t.canvas,
      canvasColor: t.canvas,
      dividerColor: t.border,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: t.canvas,
        foregroundColor: t.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: AppTheme.screenPadding,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: t.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(BuildFlowThemeExtension.cardRadius),
          side: BorderSide(color: t.border),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.muted,
          disabledForegroundColor: t.textTertiary,
          minimumSize: const Size(double.infinity, primaryActionHeight),
          shape: buttonShape,
          textStyle: AppTextTheme.button,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.graphite,
          foregroundColor: t.onGraphite,
          minimumSize: const Size(double.infinity, primaryActionHeight),
          shape: buttonShape,
          textStyle: AppTextTheme.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          backgroundColor: t.card,
          side: BorderSide(color: t.border),
          minimumSize: const Size(double.infinity, minTouchTarget),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accentText,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.textPrimary,
          minimumSize: const Size(iconButtonSize, iconButtonSize),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing16,
        ),
        border: inputBorder(),
        enabledBorder: inputBorder(),
        disabledBorder: inputBorder(),
        focusedBorder: inputBorder(
          BorderSide(color: t.textPrimary, width: 1.5),
        ),
        errorBorder: inputBorder(BorderSide(color: t.danger.fg)),
        focusedErrorBorder: inputBorder(
          BorderSide(color: t.danger.fg, width: 1.5),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: t.textSecondary),
        floatingLabelStyle:
            textTheme.bodyLarge?.copyWith(color: t.textSecondary),
        hintStyle: textTheme.bodyLarge?.copyWith(color: t.textTertiary),
        prefixIconColor: t.textSecondary,
        suffixIconColor: t.textSecondary,
        errorStyle: textTheme.bodySmall?.copyWith(color: t.danger.fg),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.textPrimary,
        unselectedLabelColor: t.textSecondary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: t.accent, width: 3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
        dividerColor: t.border,
        overlayColor: WidgetStatePropertyAll(t.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.graphite,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: t.onGraphite),
        actionTextColor: t.accent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(BuildFlowThemeExtension.inputRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: t.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BuildFlowThemeExtension.bottomSheetRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(BuildFlowThemeExtension.cardRadius),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.card,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(BuildFlowThemeExtension.inputRadius),
          side: BorderSide(color: t.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: t.muted,
        selectedColor: t.graphite,
        labelStyle: textTheme.labelMedium?.copyWith(color: t.textPrimary),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        elevation: 4,
        highlightElevation: 6,
        extendedTextStyle: AppTextTheme.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.muted,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.accent,
        inactiveTrackColor: t.muted,
        thumbColor: t.accent,
        overlayColor: t.accent.withValues(alpha: 0.16),
        valueIndicatorColor: t.graphite,
        valueIndicatorTextStyle:
            textTheme.labelMedium?.copyWith(color: t.onGraphite),
        activeTickMarkColor: t.onAccent.withValues(alpha: 0.3),
        inactiveTickMarkColor: t.textTertiary.withValues(alpha: 0.4),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : null,
        ),
        checkColor: WidgetStatePropertyAll(t.onAccent),
        side: BorderSide(color: t.textTertiary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : t.textTertiary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onAccent : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : null,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: t.graphite,
          selectedForegroundColor: t.onGraphite,
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.border),
          textStyle: textTheme.labelLarge,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle:
            textTheme.bodySmall?.copyWith(color: t.textSecondary),
      ),
      extensions: [t],
    );
  }
}
