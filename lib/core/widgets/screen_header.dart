import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

/// Large title of a bottom-navigation tab: an optional small [overline]
/// (greeting, date) above a 30/w800 [title], [actions] on the right.
///
/// Tab screens use it instead of an AppBar; screens pushed over the
/// navigation keep a regular AppBar.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    this.overline,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? overline;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spacing16,
        AppTheme.screenPadding,
        AppTheme.spacing16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(
                    overline!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.bfTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.headlineLarge),
                ),
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: AppTheme.spacing8),
            action,
          ],
        ],
      ),
    );
  }
}
