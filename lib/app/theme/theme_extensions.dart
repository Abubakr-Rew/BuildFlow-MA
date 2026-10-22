import 'package:buildflow/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Custom ThemeExtension for tokens not covered by Material 3.
class BuildFlowThemeExtension extends ThemeExtension<BuildFlowThemeExtension> {
  const BuildFlowThemeExtension({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.cardBorderRadius,
    required this.inputBorderRadius,
    required this.bottomSheetBorderRadius,
    required this.draftColor,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final double cardBorderRadius;
  final double inputBorderRadius;
  final double bottomSheetBorderRadius;
  final Color draftColor;

  static const light = BuildFlowThemeExtension(
    success: AppColors.successLight,
    onSuccess: Colors.white,
    warning: AppColors.warningLight,
    onWarning: Colors.white,
    cardBorderRadius: 12,
    inputBorderRadius: 12,
    bottomSheetBorderRadius: 20,
    draftColor: AppColors.warningLight,
  );

  static const dark = BuildFlowThemeExtension(
    success: AppColors.successDark,
    onSuccess: Colors.black,
    warning: AppColors.warningDark,
    onWarning: Colors.black,
    cardBorderRadius: 12,
    inputBorderRadius: 12,
    bottomSheetBorderRadius: 20,
    draftColor: AppColors.warningDark,
  );

  @override
  BuildFlowThemeExtension copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    double? cardBorderRadius,
    double? inputBorderRadius,
    double? bottomSheetBorderRadius,
    Color? draftColor,
  }) {
    return BuildFlowThemeExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      inputBorderRadius: inputBorderRadius ?? this.inputBorderRadius,
      bottomSheetBorderRadius:
          bottomSheetBorderRadius ?? this.bottomSheetBorderRadius,
      draftColor: draftColor ?? this.draftColor,
    );
  }

  @override
  BuildFlowThemeExtension lerp(
    covariant BuildFlowThemeExtension? other,
    double t,
  ) {
    if (other == null) return this;
    return BuildFlowThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      cardBorderRadius:
          cardBorderRadius + (other.cardBorderRadius - cardBorderRadius) * t,
      inputBorderRadius:
          inputBorderRadius + (other.inputBorderRadius - inputBorderRadius) * t,
      bottomSheetBorderRadius: bottomSheetBorderRadius +
          (other.bottomSheetBorderRadius - bottomSheetBorderRadius) * t,
      draftColor: Color.lerp(draftColor, other.draftColor, t)!,
    );
  }
}

/// Extension for convenient access from BuildContext.
extension BuildFlowThemeX on BuildContext {
  BuildFlowThemeExtension get bfTheme =>
      Theme.of(this).extension<BuildFlowThemeExtension>()!;
}
