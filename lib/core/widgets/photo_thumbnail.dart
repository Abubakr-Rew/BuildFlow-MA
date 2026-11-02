import 'dart:io';
import 'dart:math';

import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/remote_files/remote_files_providers.dart';
import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// placeholder, a local file or a Storage file (`storage:`, downloaded
/// once into the cache by `RemoteFiles`). No hero, no rounding.
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
    if (StorageRef.tryParse(url) case final ref?) {
      return _StoragePhoto(storageRef: ref, fit: fit, iconSize: iconSize);
    }
    // Photos taken on this device are stored as local file paths.
    if (!url.startsWith('http')) {
      return _LocalPhoto(path: url, fit: fit, iconSize: iconSize);
    }
    return _FakePlaceholder(seed: url, iconSize: iconSize);
  }
}

/// A photo file on the phone, decoded at about the size shown.
class _LocalPhoto extends StatelessWidget {
  const _LocalPhoto({
    required this.path,
    required this.fit,
    required this.iconSize,
  });

  final String path;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
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
                PhotoImage._maxDecodeWidth,
              )
            : null;
        return Image.file(
          File(path),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: decodeWidth,
          // The original gives way to its copy without a blank frame.
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              _FakePlaceholder(seed: path, iconSize: iconSize),
        );
      },
    );
  }
}

/// A photo from Storage: a quiet tile while it downloads, then the file.
class _StoragePhoto extends ConsumerStatefulWidget {
  const _StoragePhoto({
    required this.storageRef,
    required this.fit,
    required this.iconSize,
  });

  final StorageRef storageRef;
  final BoxFit fit;
  final double iconSize;

  @override
  ConsumerState<_StoragePhoto> createState() => _StoragePhotoState();
}

class _StoragePhotoState extends ConsumerState<_StoragePhoto> {
  late Future<Result<String>> _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_StoragePhoto old) {
    super.didUpdateWidget(old);
    if (old.storageRef != widget.storageRef) _load();
  }

  void _load() =>
      _file = ref.read(remoteFilesProvider).localPath(widget.storageRef);

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return FutureBuilder<Result<String>>(
      future: _file,
      builder: (context, snapshot) => switch (snapshot.data) {
        Success(value: final path) =>
          _LocalPhoto(path: path, fit: widget.fit, iconSize: widget.iconSize),
        // Didn't download: tap to try again.
        Err() => GestureDetector(
            onTap: () => setState(_load),
            child: ColoredBox(
              color: t.muted,
              child: Center(
                child: Icon(
                  Icons.refresh_rounded,
                  size: min(widget.iconSize, 32),
                  color: t.textTertiary,
                ),
              ),
            ),
          ),
        null => ColoredBox(color: t.muted),
      },
    );
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
