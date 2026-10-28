import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/entities/report_photo.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full report: project, author, date, text and all photos.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({required this.reportId, super.key});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final report = ref.watch(reportByIdProvider(reportId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportDetailTitle)),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: l10n.failureMessage(error),
          onRetry: () => ref.invalidate(reportsProvider),
          retryLabel: l10n.retry,
        ),
        data: (report) => report == null
            ? EmptyState(
                icon: Icons.article_outlined,
                title: l10n.reportNotFound,
              )
            : _ReportBody(report: report),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report});

  final Report report;

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
    final date = DateFormatter.full(report.createdAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spacing8,
        AppTheme.screenPadding,
        AppTheme.spacing32,
      ),
      children: [
        // Project — tap to open it
        BfCard(
          onTap: () => context.push(Routes.project(report.projectId)),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.muted,
                  borderRadius: BorderRadius.circular(
                    BuildFlowThemeExtension.photoRadius,
                  ),
                ),
                child: Icon(Icons.construction_rounded, color: t.textPrimary),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  report.projectName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.cardGap),

        // Author, date and text
        BfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarInitials(name: report.authorName, size: 44),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.authorName,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          role == null ? date : '${role.label(l10n)} · $date',
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
              const SizedBox(height: AppTheme.spacing16),
              Text(report.text, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),

        if (report.photos.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing24),
          Text(
            '${l10n.photos} · ${l10n.photosCount(report.photos.length)}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppTheme.spacing12),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final size = (constraints.maxWidth - spacing * 2) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var i = 0; i < report.photos.length; i++)
                    PhotoThumbnail(
                      photoId: _heroId(report, report.photos[i]),
                      url: report.photos[i].url,
                      size: size,
                      onTap: () => _openViewer(context, report, i),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  void _openViewer(BuildContext context, Report report, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoViewer(report: report, initialIndex: index),
      ),
    );
  }
}

String _heroId(Report report, ReportPhoto photo) =>
    '${report.id}-detail-${photo.id}';

/// Swipeable full-screen photo viewer.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.report, required this.initialIndex});

  final Report report;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photos = widget.report.photos;

    final t = context.bfTheme;

    return Scaffold(
      backgroundColor: t.graphite,
      appBar: AppBar(
        backgroundColor: t.graphite,
        foregroundColor: t.onGraphite,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: t.onGraphite),
        title: Text(l10n.photoOf(_index + 1, photos.length)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => Center(
          child: InteractiveViewer(
            child: LayoutBuilder(
              builder: (context, constraints) => PhotoThumbnail(
                photoId: _heroId(widget.report, photos[i]),
                url: photos[i].url,
                size: constraints.maxWidth,
                borderRadius: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
