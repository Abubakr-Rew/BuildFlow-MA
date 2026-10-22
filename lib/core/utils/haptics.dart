import 'package:flutter/services.dart';

/// Haptic feedback helpers for physical interactions.
abstract final class Haptics {
  /// Light impact for button taps.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Medium impact for confirmations.
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Heavy impact for submit actions.
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Selection click for toggles and pickers.
  static Future<void> selection() => HapticFeedback.selectionClick();
}
