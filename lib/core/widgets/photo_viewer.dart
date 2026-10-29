import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/bf_icon_button.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/core/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One photo of the full-screen viewer and what is said under it.
@immutable
class ViewerPhoto {
  const ViewerPhoto({
    required this.url,
    this.heroTag,
    this.aspectRatio,
    this.caption,
    this.author,
    this.time,
    this.warning,
  });

  final String url;

  /// The `Hero` tag of the thumbnail it opens from.
  final Object? heroTag;

  /// Width / height, when known; a `fake:` demo photo is drawn in it.
  final double? aspectRatio;

  /// The text sent with the photo, e.g. a chat message's caption.
  final String? caption;

  /// Who sent it and when: «Бакыт Касымов», «Сегодня, 11:47».
  final String? author;
  final String? time;

  /// A badge under the photo, e.g. «Снято не сегодня».
  final String? warning;
}

/// Opens [photos] full screen at [initialIndex], over the bottom navigation.
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<ViewerPhoto> photos,
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      // Transparent, so the screen below shows while swiping down to close.
      opaque: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) =>
          PhotoViewer(photos: photos, initialIndex: initialIndex),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Full-screen photos of a report or a chat message: swipe sideways to the
/// next one, pinch or double-tap to zoom, swipe down to close. The caption,
/// author and time are at the bottom.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({required this.photos, this.initialIndex = 0, super.key});

  final List<ViewerPhoto> photos;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  /// Dragged further down than this, or flung, the viewer closes.
  static const _dismissDistance = 120.0;
  static const _dismissVelocity = 800.0;

  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  /// While zoomed in, one finger pans the photo instead of paging or
  /// closing.
  bool _zoomed = false;
  double _drag = 0;
  bool _dragging = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) => setState(() {
        _dragging = true;
        _drag += details.delta.dy;
      });

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_drag.abs() > _dismissDistance || velocity.abs() > _dismissVelocity) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _dragging = false;
      _drag = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    final photo = widget.photos[_index];
    // The background and the bars fade as the photo is dragged away.
    final fade = 1 - (_drag.abs() / (_dismissDistance * 3)).clamp(0.0, 0.7);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: t.graphite.withValues(alpha: fade),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
                onVerticalDragEnd: _zoomed ? null : _onDragEnd,
                child: AnimatedContainer(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(0, _drag, 0),
                  child: PageView.builder(
                    controller: _pages,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: widget.photos.length,
                    onPageChanged: (i) => setState(() {
                      _index = i;
                      _zoomed = false;
                    }),
                    itemBuilder: (_, i) => _ZoomablePhoto(
                      photo: widget.photos[i],
                      onZoomChanged: (zoomed) {
                        if (zoomed != _zoomed) {
                          setState(() => _zoomed = zoomed);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: fade,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    child: Row(
                      children: [
                        BfIconButton(
                          icon: Icons.close_rounded,
                          tooltip: l10n.photoViewerClose,
                          translucent: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        if (widget.photos.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppTheme.spacing8,
                            ),
                            child: Text(
                              l10n.photoOf(_index + 1, widget.photos.length),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: t.onGraphite,
                                    fontFeatures: AppTextTheme.tabular,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: fade,
                child: _Details(photo: photo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caption, author and time, and the warning badge, over a scrim that keeps
/// them readable on a tall photo.
class _Details extends StatelessWidget {
  const _Details({required this.photo});

  final ViewerPhoto photo;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final theme = Theme.of(context);
    final meta = [
      if (photo.author case final author?) author,
      if (photo.time case final time?) time,
    ].join(' · ');
    if (photo.caption == null && meta.isEmpty && photo.warning == null) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.graphite.withValues(alpha: 0),
            t.graphite.withValues(
              alpha: BuildFlowThemeExtension.coverScrimOpacity,
            ),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.spacing32,
            AppTheme.screenPadding,
            AppTheme.spacing16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photo.caption case final caption?) ...[
                Text(
                  caption,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: t.onGraphite,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
              ],
              if (meta.isNotEmpty)
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: t.onGraphiteSecondary,
                    fontFeatures: AppTextTheme.tabular,
                  ),
                ),
              if (photo.warning case final warning?) ...[
                const SizedBox(height: AppTheme.spacing8),
                StatusBadge(
                  label: warning,
                  tone: StatusTone.paused,
                  icon: Icons.history_rounded,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One page: the photo fitted to the screen, zoomable up to 5×.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.photo, required this.onZoomChanged});

  final ViewerPhoto photo;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  static const _doubleTapScale = 2.5;

  final _transform = TransformationController();
  Offset _doubleTapAt = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() {
      final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed) {
        setState(() => _zoomed = zoomed);
        widget.onZoomChanged(zoomed);
      }
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    final at = _doubleTapAt;
    // Zooms in around the tapped point.
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -at.dx * (_doubleTapScale - 1),
        -at.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  Widget _image() {
    final photo = widget.photo;
    final image = photo.url.startsWith('fake:')
        ? Center(
            child: AspectRatio(
              aspectRatio: photo.aspectRatio ?? 4 / 3,
              child: PhotoImage(url: photo.url, iconSize: 96),
            ),
          )
        : PhotoImage(url: photo.url, fit: BoxFit.contain);
    return switch (photo.heroTag) {
      final tag? => Hero(tag: tag, child: image),
      null => image,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 5,
        // Unzoomed, one finger belongs to paging and swipe-to-close.
        panEnabled: _zoomed,
        child: SizedBox.expand(child: _image()),
      ),
    );
  }
}
