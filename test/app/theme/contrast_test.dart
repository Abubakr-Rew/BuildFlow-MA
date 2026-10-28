import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2 contrast ratio of two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group('$name theme text contrast ≥ 4.5', () {
      final t = theme.extension<BuildFlowThemeExtension>()!;
      final scheme = theme.colorScheme;
      final scrimmedWhite = Color.alphaBlend(
        t.graphite.withValues(
          alpha: BuildFlowThemeExtension.coverScrimOpacity,
        ),
        const Color(0xFFFFFFFF),
      );

      final pairs = <String, (Color, Color)>{
        for (final (bgName, bg) in [
          ('canvas', t.canvas),
          ('card', t.card),
          ('muted', t.muted),
        ]) ...{
          'textPrimary on $bgName': (t.textPrimary, bg),
          'textSecondary on $bgName': (t.textSecondary, bg),
          'textTertiary on $bgName': (t.textTertiary, bg),
        },
        'onAccent on accent': (t.onAccent, t.accent),
        'accentText on canvas': (t.accentText, t.canvas),
        'accentText on card': (t.accentText, t.card),
        'onGraphite on graphite': (t.onGraphite, t.graphite),
        'onGraphiteSecondary on graphite': (t.onGraphiteSecondary, t.graphite),
        'accent on graphite (snack bar action)': (t.accent, t.graphite),
        'active': (t.active.fg, t.active.bg),
        'paused': (t.paused.fg, t.paused.bg),
        'danger': (t.danger.fg, t.danger.bg),
        'finished': (t.finished.fg, t.finished.bg),
        'active on card (report time)': (t.active.fg, t.card),
        'danger on card (field error)': (t.danger.fg, t.card),
        'danger on muted (field error)': (t.danger.fg, t.muted),
        for (final (i, a) in t.avatars.indexed) 'avatar $i': (a.fg, a.bg),
        // Header text over a white cover photo under the scrim.
        'onGraphite on scrimmed white cover': (t.onGraphite, scrimmedWhite),
        'onGraphiteSecondary on scrimmed white cover': (
          t.onGraphiteSecondary,
          scrimmedWhite,
        ),
        // Search match highlight: translucent accent laid over the card.
        'textPrimary on matchHighlight': (
          t.textPrimary,
          Color.alphaBlend(t.matchHighlight, t.card),
        ),
        'onError on error': (scheme.onError, scheme.error),
        'onPrimaryContainer on primaryContainer': (
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        ),
      };

      for (final MapEntry(key: pair, value: (fg, bg)) in pairs.entries) {
        test(pair, () {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
        });
      }
    });
  }
}
