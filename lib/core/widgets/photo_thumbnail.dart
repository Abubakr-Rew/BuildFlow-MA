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
            child: _buildImage(context),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (url.startsWith('fake:')) {
      return _FakePlaceholder(seed: url, size: size);
    }
    // Photos taken on this device are stored as local file paths.
    if (!url.startsWith('http')) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _FakePlaceholder(seed: url, size: size),
      );
    }
    // Real images will use CachedNetworkImage in the future
    return _FakePlaceholder(seed: url, size: size);
  }
}

/// Colored placeholder with construction icon for demo data.
class _FakePlaceholder extends StatelessWidget {
  const _FakePlaceholder({required this.seed, required this.size});

  final String seed;
  final double size;

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
        size: size * 0.4,
        color: context.bfTheme.onGraphite.withValues(alpha: 0.7),
      ),
    );
  }
}
