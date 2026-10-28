import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Up to two capital letters from a name: «Бакыт Касымов» → «БК»,
/// «Бакыт» → «Б». Empty for a blank name.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// Round avatar with the initials of [name] on a pastel background.
/// The color is stable for a given name.
class AvatarInitials extends StatelessWidget {
  const AvatarInitials({
    required this.name,
    this.size = 40,
    this.borderColor,
    super.key,
  });

  final String name;
  final double size;

  /// Ring around the avatar, used by [AvatarStack] to separate overlaps.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tone = context.bfTheme.avatarFor(name);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.bg,
          shape: BoxShape.circle,
          border: borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 2),
        ),
        child: Text(
          initialsOf(name),
          maxLines: 1,
          style: TextStyle(
            color: tone.fg,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Overlapping avatars; past [max] the last circle shows «+N».
///
/// Each circle is ringed in the card color and overlaps the previous one by
/// [overlap] of its size, so at least 80 % of every circle, and both
/// initials, stay visible.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    required this.names,
    this.size = 32,
    this.max = 5,
    super.key,
  });

  final List<String> names;
  final double size;
  final int max;

  /// Share of a circle hidden under the next one.
  static const overlap = 0.2;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final overflow = names.length > max ? names.length - (max - 1) : 0;
    final shown = overflow > 0 ? names.take(max - 1).toList() : names;
    final count = shown.length + (overflow > 0 ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();

    final step = size * (1 - overlap);
    return SizedBox(
      width: size + step * (count - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: AvatarInitials(
                name: shown[i],
                size: size,
                borderColor: t.card,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: step * shown.length,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.muted,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.card, width: 2),
                ),
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
