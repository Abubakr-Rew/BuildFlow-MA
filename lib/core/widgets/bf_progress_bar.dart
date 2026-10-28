import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Accent progress bar on a muted track. [percent] is 0–100.
class BfProgressBar extends StatelessWidget {
  const BfProgressBar({
    required this.percent,
    this.height = 8,
    super.key,
  });

  final int percent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Semantics(
      value: '$percent%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: t.muted),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percent.clamp(0, 100) / 100,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
