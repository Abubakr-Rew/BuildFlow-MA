import 'dart:io';
import 'dart:math';

import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Displays a photo thumbnail with Hero animation support.
/// Handles both fake:// scheme (colored placeholder) and real image URLs.
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    required this.photoId,
    required this.url,
    this.size = 80,
    this.borderRadius = BuildFlowThemeExtension.photoRadius,
    this.onTap,
    super.key,
  });

  final String photoId;
  final String url;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'photo_$photoId',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            width: size,
            height: size,
            child: PhotoImage(url: url, iconSize: size * 0.4),
          ),
        ),
      ),
    );
  }

}

/// A photo filling its parent, cropped to cover it by default: a `fake:`
/// placeholder, a local file or (later) a network image. No hero, no
/// rounding.
///
/// Local files are decoded at about the size shown, not at the camera's
/// 12 MP: a picked original is shown until its compressed copy is sent.
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    required this.url,
    this.iconSize = 32,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String url;

  /// Icon size on a `fake:` placeholder.
  final double iconSize;
  final BoxFit fit;

  /// Largest decode width; enough for a full-screen zoom.
  static const _maxDecodeWidth = 4096;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('fake:')) {
      return _FakePlaceholder(seed: url, iconSize: iconSize);
    }
    // Photos taken on this device are stored as local file paths.
    if (!url.startsWith('http')) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = max(constraints.maxWidth, constraints.maxHeight);
          // A cropped photo needs more than the box's width: twice the
          // longer side covers photos up to 2:1.
          final factor = fit == BoxFit.cover ? 2 : 1;
          final decodeWidth = side.isFinite
              ? min(
                  (side * MediaQuery.devicePixelRatioOf(context) * factor)
                      .round(),
                  _maxDecodeWidth,
                )
              : null;
          return Image.file(
            File(url),
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: decodeWidth,
            // The original gives way to its copy without a blank frame.
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                _FakePlaceholder(seed: url, iconSize: iconSize),
          );
        },
      );
    }
    // Real images will use CachedNetworkImage in the future
    return _FakePlaceholder(seed: url, iconSize: iconSize);
  }
}

/// Colored placeholder with construction icon for demo data.
class _FakePlaceholder extends StatelessWidget {
  const _FakePlaceholder({required this.seed, required this.iconSize});

  final String seed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final hash = seed.hashCode;
    final random = Random(hash);
    final colors = context.bfTheme.photoPlaceholders;

    final icons = [
      Icons.construction,
      Icons.home_work,
      Icons.foundation,
      Icons.engineering,
      Icons.architecture,
      Icons.apartment,
      Icons.roofing,
      Icons.handyman,
    ];

    final colorIndex = random.nextInt(colors.length);
    final iconIndex = random.nextInt(icons.length);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[colorIndex],
            colors[colorIndex].withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Icon(
        icons[iconIndex],
        size: iconSize,
        color: context.bfTheme.onGraphite.withValues(alpha: 0.7),
      ),
    );
  }
}
