import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/widgets/app_logo.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Splash screen — restores the session; the router's redirect then
/// navigates away once the auth status is known.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    // restoreSession() updates authProvider, which the router listens to;
    // providers must not change while the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
  }

  Future<void> _restoreSession() async {
    try {
      await ref
          .read(authProvider.notifier)
          .restoreSession()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // If restoreSession itself throws or times out, force unauthenticated.
      // Resetting the state clears isLoading, and the router's redirect
      // then leaves the splash for login.
      if (mounted &&
          ref.read(authProvider).status == AuthStatus.initial) {
        ref.read(authProvider.notifier).forceUnauthenticated();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 100),
                const SizedBox(height: AppTheme.spacing24),
                Text(
                  l10n.appName,
                  style: theme.textTheme.displayLarge,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  l10n.appTagline,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.bfTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing48),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
