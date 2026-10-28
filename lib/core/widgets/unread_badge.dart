import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Accent counter of unread items: on a navigation tab, a chat row or the
/// project chat tile. Shows «99+» past 99; draws nothing for 0.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    required this.count,
    this.ringColor,
    super.key,
  });

  final int count;

  /// Ring around the badge, to keep it visible over an accent pill.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final t = context.bfTheme;
    final ring = ringColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: t.accent,
        shape: StadiumBorder(
          side: ring == null
              ? BorderSide.none
              : BorderSide(color: ring, width: 2),
        ),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: t.onAccent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
          fontFeatures: AppTextTheme.tabular,
        ),
      ),
    );
  }
}
