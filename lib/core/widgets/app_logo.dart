import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// App mark: an accent helmet-and-crane icon on a graphite square.
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.graphite,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.construction_rounded,
        size: size * 0.55,
        color: t.accent,
      ),
    );
  }
}
