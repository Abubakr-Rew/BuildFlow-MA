import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/photos/photo_draft.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:flutter/material.dart';

/// A picked photo on the new report and above the chat message field: the
/// photo, a spinner while it's compressed, and a remove button in the
/// corner. If compressing failed, a red mark covers it instead and the
/// whole tile opens [onFailedTap] («Повторить / Удалить»): on a small tile
/// the corner button's tap area would cover the mark.
class PhotoDraftTile extends StatelessWidget {
  const PhotoDraftTile({
    required this.draft,
    required this.size,
    required this.onRemove,
    this.onFailedTap,
    super.key,
  });

  final PhotoDraft draft;
  final double size;
  final VoidCallback onRemove;
  final VoidCallback? onFailedTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                BuildFlowThemeExtension.photoRadius,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PhotoImage(url: draft.sourcePath, iconSize: size * 0.4),
                  if (draft.isProcessing)
                    ColoredBox(
                      color: t.graphite.withValues(alpha: 0.45),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: t.onGraphite,
                            semanticsLabel: l10n.photoProcessing,
                          ),
                        ),
                      ),
                    ),
                  if (draft.isFailed)
                    Material(
                      color: t.graphite.withValues(alpha: 0.55),
                      child: InkWell(
                        onTap: onFailedTap,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(AppTheme.spacing4),
                            decoration: BoxDecoration(
                              color: t.danger.bg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline_rounded,
                              size: 22,
                              color: t.danger.fg,
                              semanticLabel: l10n.photoProcessingFailed,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // The visible circle is 26 px; the tap area is 44.
          if (!draft.isFailed)
            Positioned(
              top: 0,
              right: 0,
              child: Tooltip(
                message: l10n.removePhoto,
                child: InkResponse(
                  onTap: onRemove,
                  radius: 22,
                  child: SizedBox.square(
                    dimension: AppTheme.iconButtonSize,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: t.graphite.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: t.onGraphite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
