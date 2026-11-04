import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/core/widgets/screen_header.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/reports/domain/report_days.dart';
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
    final isForeman =
        ref.watch(currentUserProvider)?.role == UserRole.foreman;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              // The foreman's tab is «История», next to the new report.
              title: isForeman ? l10n.reportHistoryTitle : l10n.reportsTitle,
            ),
            Expanded(
              child: RefreshIndicator(
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
                    final days = groupReportsByDay(list);
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.screenPadding,
                        0,
                        AppTheme.screenPadding,
                        AppTheme.spacing24,
                      ),
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
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
                                DateFormatter.relative(
                                  day.day,
                                  today: l10n.today,
                                  yesterday: l10n.yesterday,
                                ),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: context.bfTheme.textSecondary,
                                    ),
                              ),
                            ),
                            ...day.reports.map(
                              (report) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppTheme.cardGap,
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
            ),
          ],
        ),
      ),
    );
  }
}
