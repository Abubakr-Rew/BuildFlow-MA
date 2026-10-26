import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/presentation/providers/report_provider.dart';
import 'package:buildflow/features/reports/presentation/widgets/report_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Report list screen — grouped by date.
class ReportListScreen extends ConsumerWidget {
  const ReportListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportsTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(reportsProvider.future),
        child: reports.when(
          loading: () => const LoadingShimmerList(),
          error: (error, _) => ErrorState(
            message: l10n.failureMessage(error),
            onRetry: () => ref.invalidate(reportsProvider),
            retryLabel: l10n.retry,
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.article_outlined,
                title: l10n.noReports,
              );
            }
            // Group by date
            final grouped = _groupByDate(list, l10n);
            return ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final group = grouped[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0)
                      const SizedBox(height: AppTheme.spacing16),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 4,
                        bottom: AppTheme.spacing8,
                      ),
                      child: Text(
                        group.dateLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    ...group.reports.map(
                      (report) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacing12,
                        ),
                        child: ReportCard(report: report),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<Report> reports, AppLocalizations l10n) {
    final groups = <DateTime, List<Report>>{};
    for (final report in reports) {
      final dateKey = DateFormatter.toDateOnly(report.createdAt);
      groups.putIfAbsent(dateKey, () => []).add(report);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return sortedKeys.map((date) {
      final label = DateFormatter.relative(
        date,
        today: l10n.today,
        yesterday: l10n.yesterday,
      );
      return _DateGroup(dateLabel: label, reports: groups[date]!);
    }).toList();
  }
}

class _DateGroup {
  const _DateGroup({required this.dateLabel, required this.reports});

  final String dateLabel;
  final List<Report> reports;
}
