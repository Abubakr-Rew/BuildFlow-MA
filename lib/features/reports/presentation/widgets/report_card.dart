import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Report preview card; tapping opens the report detail screen.
class ReportCard extends StatelessWidget {
  const ReportCard({
    required this.report,
    this.showProject = true,
    super.key,
  });

  final Report report;

  /// Hide the project name when the card is already shown inside a project.
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.report(report.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: project name (or author) + time
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      showProject ? report.projectName : report.authorName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    showProject
                        ? DateFormatter.time(report.createdAt)
                        : DateFormatter.full(report.createdAt),
                    style: muted,
                  ),
                ],
              ),
              if (showProject) ...[
                const SizedBox(height: AppTheme.spacing8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(report.authorName, style: muted),
                  ],
                ),
              ],
              const SizedBox(height: AppTheme.spacing12),

              Text(
                report.text,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              if (report.photos.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing12),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: report.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final photo = report.photos[index];
                      return PhotoThumbnail(
                        photoId: '${report.id}-card-${photo.id}',
                        url: photo.url,
                        size: 72,
                        onTap: () => context.push(Routes.report(report.id)),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
