import 'dart:math';

import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:flutter/material.dart';

/// Photos a grid shows at most; the last cell then says «+N».
const maxGridPhotos = 4;

/// Cells per row of a message's photo grid: one photo alone; two side by
/// side; three as one wide and two below; four and more as 2 × 2.
List<int> photoGridRows(int count) => switch (count) {
  <= 0 => const [],
  1 => const [1],
  2 => const [2],
  3 => const [1, 2],
  _ => const [2, 2],
};

/// The `Hero` tag of photo [index] of [message], shared with the viewer.
String chatPhotoHeroTag(Message message, int index) =>
    'chat-photo-${message.id}-$index';

/// The photos of a message, [width] wide: one by its proportions, more in
/// a grid. While the user's message is being sent each photo shows its
/// upload ([uploadProgress]); tapping one calls [onTap] with its index.
class MessagePhotos extends StatelessWidget {
  const MessagePhotos({
    required this.message,
    required this.width,
    required this.radius,
    this.uploadProgress = const {},
    this.onTap,
    super.key,
  });

  final Message message;
  final double width;
  final BorderRadius radius;
  final Map<String, double> uploadProgress;
  final ValueChanged<int>? onTap;

  static const gap = 2.0;

  /// A single photo keeps its proportions within these.
  static const _minAspect = 0.6;
  static const _maxAspect = 1.8;

  /// Height of the wide top cell of three photos, per width.
  static const _wideCell = 0.56;

  @override
  Widget build(BuildContext context) {
    final photos = message.attachments;
    final rows = photoGridRows(photos.length);
    final cells = <Widget>[];
    var index = 0;
    for (final (r, perRow) in rows.indexed) {
      if (r > 0) cells.add(const SizedBox(height: gap));
      final cellWidth = (width - gap * (perRow - 1)) / perRow;
      final height = switch ((photos.length, perRow)) {
        (1, _) => width / _aspectOf(photos.single),
        (_, 1) => width * _wideCell,
        _ => cellWidth,
      };
      cells.add(
        SizedBox(
          height: height,
          child: Row(
            children: [
              for (var c = 0; c < perRow; c++, index++) ...[
                if (c > 0) const SizedBox(width: gap),
                SizedBox(width: cellWidth, child: _cell(context, index)),
              ],
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, children: cells),
      ),
    );
  }

  static double _aspectOf(MessageAttachment photo) {
    final (w, h) = (photo.width, photo.height);
    if (w == null || h == null || w <= 0 || h <= 0) return 4 / 3;
    return (w / h).clamp(_minAspect, _maxAspect);
  }

  Widget _cell(BuildContext context, int index) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    final photos = message.attachments;
    final photo = photos[index];
    final hidden = index == maxGridPhotos - 1 ? photos.length - index - 1 : 0;
    final progress = uploadProgress[photo.id];
    final uploading =
        message.status.isPending && (progress == null || progress < 1);

    return Semantics(
      button: onTap != null,
      label: l10n.photoOf(index + 1, photos.length),
      child: GestureDetector(
        onTap: onTap == null ? null : () => onTap!(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: chatPhotoHeroTag(message, index),
              child: PhotoImage(url: photo.url, iconSize: min(width / 4, 48)),
            ),
            if (hidden > 0)
              ColoredBox(
                color: t.graphite.withValues(alpha: 0.6),
                child: Center(
                  child: Text(
                    l10n.morePhotos(hidden + 1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: t.onGraphite,
                      fontFeatures: AppTextTheme.tabular,
                    ),
                  ),
                ),
              ),
            if (uploading)
              ColoredBox(
                color: t.graphite.withValues(alpha: 0.45),
                child: Center(
                  child: SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: t.onGraphite,
                      backgroundColor: t.onGraphite.withValues(alpha: 0.25),
                      semanticsLabel: l10n.photoUploading,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
