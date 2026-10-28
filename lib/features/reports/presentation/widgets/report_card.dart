import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Report preview card; tapping opens the report detail screen.
///
/// Author (avatar, name, role · time), text and up to three photos;
/// the third shows «+N» when there are more.
class ReportCard extends ConsumerWidget {
  const ReportCard({required this.report, this.showProject = true, super.key});

  final Report report;

  /// Hide the project name when the card is already shown inside a project.
  final bool showProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    // The report has no role; take it from the team when the author is there.
    final role = ref
        .watch(membersProvider)
        .valueOrNull
        ?.where((m) => m.userId == report.authorId)
        .firstOrNull
        ?.role;
    // The report list already groups cards under a day header.
    final time = showProject
        ? DateFormatter.time(report.createdAt)
        : DateFormatter.reportDateTime(
            report.createdAt,
            today: l10n.today,
            yesterday: l10n.yesterday,
          );

    return BfCard(
      onTap: () => context.push(Routes.report(report.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showProject) ...[
            Row(
              children: [
                Icon(
                  Icons.construction_rounded,
                  size: 16,
                  color: t.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    report.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: t.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
          ],
          Row(
            children: [
              AvatarInitials(name: report.authorName),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.authorName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      role == null ? time : '${role.label(l10n)} · $time',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: t.textTertiary,
                        fontFeatures: AppTextTheme.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            report.text,
            style: theme.textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (report.photos.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing12),
            _PhotoStrip(report: report),
          ],
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.report});

  static const _cells = 3;
  static const _gap = 6.0;

  final Report report;

  @override
  Widget build(BuildContext context) {
    final photos = report.photos;
    final shown = photos.take(_cells).toList();
    // The last cell is covered by the counter, so it counts as hidden too.
    final hidden = photos.length > _cells ? photos.length - (_cells - 1) : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - _gap * (_cells - 1)) / _cells;
        return Row(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Stack(
                children: [
                  PhotoThumbnail(
                    photoId: '${report.id}-card-${shown[i].id}',
                    url: shown[i].url,
                    size: size,
                    onTap: () => context.push(Routes.report(report.id)),
                  ),
                  if (hidden > 0 && i == _cells - 1)
                    Positioned.fill(child: _MoreOverlay(count: hidden)),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MoreOverlay extends StatelessWidget {
  const _MoreOverlay({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.graphite.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(
            BuildFlowThemeExtension.photoRadius,
          ),
        ),
        child: Center(
          child: Text(
            '+$count',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: t.onGraphite,
              fontFeatures: AppTextTheme.tabular,
            ),
          ),
        ),
      ),
    );
  }
}
