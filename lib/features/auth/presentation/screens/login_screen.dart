import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/utils/validators.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_text_field.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Login screen — email + password, link to register.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (success && mounted) {
      final user = ref.read(authProvider).user!;
      if (user.role.isOwner) {
        context.go(Routes.ownerProjects);
      } else {
        context.go(Routes.foremanProjects);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.construction_rounded,
                        size: 40,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    Text(l10n.loginTitle, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      'BuildFlow',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),
                    BfTextField(
                      label: l10n.email,
                      hint: l10n.emailHint,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.email_outlined,
                      validator: (v) => Validators.email(
                        v,
                        requiredMsg: l10n.validationEmailRequired,
                        invalidMsg: l10n.validationEmailInvalid,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    BfTextField(
                      label: l10n.password,
                      hint: l10n.passwordHint,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outlined,
                      onFieldSubmitted: (_) => _submit(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (v) => Validators.password(
                        v,
                        requiredMsg: l10n.validationPasswordRequired,
                        shortMsg: l10n.validationPasswordShort,
                      ),
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: AppTheme.spacing12),
                      Text(
                        auth.errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing24),
                    BfButton(
                      label: l10n.loginButton,
                      onPressed: _submit,
                      isLoading: auth.isLoading,
                      icon: Icons.login_rounded,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l10n.noAccount, style: theme.textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => context.go(Routes.register),
                          child: Text(l10n.registerButton),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing32),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Демо-доступ:',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Владелец: owner@buildflow.kg\n'
                            'Прораб: foreman1@buildflow.kg\n'
                            'Пароль: 123456',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
