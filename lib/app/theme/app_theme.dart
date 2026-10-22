import 'package:buildflow/app/theme/app_colors.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Material 3 theme with construction-friendly palette.
abstract final class AppTheme {
  // ── 8pt spacing grid ────────────────────────────────────────
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing48 = 48;

  // ── Touch targets ──────────────────────────────────────────
  static const double minTouchTarget = 48;
  static const double primaryActionHeight = 56;

  // ── Light theme ─────────────────────────────────────────────
  static ThemeData get light {
    final textTheme = AppTextTheme.textTheme;
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryLight,
      onPrimary: AppColors.onPrimaryLight,
      primaryContainer: AppColors.primaryContainerLight,
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainerLight,
      onSecondaryContainer: AppColors.secondaryLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      surfaceContainerLow: AppColors.surfaceContainerLight,
      surfaceContainer: AppColors.surfaceContainerLight,
      surfaceContainerHigh: AppColors.surfaceContainerHighLight,
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
      errorContainer: AppColors.errorContainerLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
    );

    return _buildTheme(colorScheme, textTheme, Brightness.light);
  }

  // ── Dark theme ──────────────────────────────────────────────
  static ThemeData get dark {
    final textTheme = AppTextTheme.textTheme;
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryDark,
      onPrimary: AppColors.onPrimaryDark,
      primaryContainer: AppColors.primaryContainerDark,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondaryDark,
      onSecondary: Colors.black,
      secondaryContainer: AppColors.secondaryContainerDark,
      onSecondaryContainer: AppColors.secondaryDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      surfaceContainerLow: AppColors.surfaceContainerDark,
      surfaceContainer: AppColors.surfaceContainerDark,
      surfaceContainerHigh: AppColors.surfaceContainerHighDark,
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
      errorContainer: AppColors.errorContainerDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
    );

    return _buildTheme(colorScheme, textTheme, Brightness.dark);
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    TextTheme textTheme,
    Brightness brightness,
  ) {
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isLight ? 1 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isLight
              ? BorderSide.none
              : BorderSide(color: colorScheme.outlineVariant),
        ),
        color: colorScheme.surfaceContainer,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, primaryActionHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, primaryActionHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: isLight ? 2 : 0,
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      extensions: [
        if (isLight)
          BuildFlowThemeExtension.light
        else
          BuildFlowThemeExtension.dark,
      ],
    );
  }
}
