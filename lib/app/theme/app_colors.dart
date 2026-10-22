import 'package:flutter/material.dart';

/// Construction-friendly color palette.
/// Deep graphite/charcoal neutrals with safety-orange accent.
abstract final class AppColors {
  // ── Primary: Safety Orange ──────────────────────────────────
  static const primaryLight = Color(0xFFE65100);
  static const primaryDark = Color(0xFFFF8F00);
  static const primaryContainerLight = Color(0xFFFFE0B2);
  static const primaryContainerDark = Color(0xFF5D2E00);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const onPrimaryDark = Color(0xFFFFFFFF);

  // ── Secondary: Charcoal / Graphite ──────────────────────────
  static const secondaryLight = Color(0xFF37474F);
  static const secondaryDark = Color(0xFFB0BEC5);
  static const secondaryContainerLight = Color(0xFFCFD8DC);
  static const secondaryContainerDark = Color(0xFF263238);

  // ── Surface tones ───────────────────────────────────────────
  static const surfaceLight = Color(0xFFF5F5F5);
  static const surfaceDark = Color(0xFF121212);
  static const surfaceContainerLight = Color(0xFFFFFFFF);
  static const surfaceContainerDark = Color(0xFF1E1E1E);
  static const surfaceContainerHighLight = Color(0xFFF0F0F0);
  static const surfaceContainerHighDark = Color(0xFF2A2A2A);

  // ── On surface ──────────────────────────────────────────────
  static const onSurfaceLight = Color(0xFF1C1C1E);
  static const onSurfaceDark = Color(0xFFE8E8E8);
  static const onSurfaceVariantLight = Color(0xFF616161);
  static const onSurfaceVariantDark = Color(0xFFAAAAAA);

  // ── Outline ─────────────────────────────────────────────────
  static const outlineLight = Color(0xFFCCCCCC);
  static const outlineDark = Color(0xFF3A3A3A);
  static const outlineVariantLight = Color(0xFFE0E0E0);
  static const outlineVariantDark = Color(0xFF2C2C2C);

  // ── Semantic colors ─────────────────────────────────────────
  static const successLight = Color(0xFF2E7D32);
  static const successDark = Color(0xFF66BB6A);
  static const warningLight = Color(0xFFF57F17);
  static const warningDark = Color(0xFFFFD54F);
  static const errorLight = Color(0xFFC62828);
  static const errorDark = Color(0xFFEF5350);
  static const onErrorLight = Color(0xFFFFFFFF);
  static const onErrorDark = Color(0xFFFFFFFF);

  // ── Error containers ────────────────────────────────────────
  static const errorContainerLight = Color(0xFFFFCDD2);
  static const errorContainerDark = Color(0xFF4E0000);
}
