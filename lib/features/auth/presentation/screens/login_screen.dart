import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/validators.dart';
import 'package:buildflow/core/widgets/app_logo.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_card.dart';
import 'package:buildflow/core/widgets/bf_chip.dart';
import 'package:buildflow/core/widgets/bf_text_field.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _demoPassword = '123456';

const _demoAccounts = [
  (UserRole.owner, 'owner@buildflow.kg'),
  (UserRole.foreman, 'foreman1@buildflow.kg'),
  (UserRole.worker, 'worker1@buildflow.kg'),
];

/// Login screen — email + password, links to register and to join by code.
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
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    // On success the router's redirect opens the role's home screen.
    await ref.read(authProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (mounted) setState(() => _submitting = false);
  }

  void _quickLogin(String email) {
    _emailController.text = email;
    _passwordController.text = _demoPassword;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final t = context.bfTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
              vertical: AppTheme.spacing24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AppLogo(),
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    Text(l10n.loginTitle, style: theme.textTheme.headlineLarge),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      l10n.appName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: t.textSecondary,
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
                    if (auth.failure case final failure?) ...[
                      const SizedBox(height: AppTheme.spacing12),
                      Text(
                        l10n.failureMessage(failure),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.danger.fg,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing24),
                    BfButton(
                      label: l10n.loginButton,
                      onPressed: _submit,
                      isLoading: _submitting,
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
                    TextButton(
                      onPressed: () => context.go(Routes.join),
                      child: Text(l10n.haveInviteCode),
                    ),
                    const SizedBox(height: AppTheme.spacing32),
                    BfCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.quickLogin,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (role, email) in _demoAccounts)
                                BfChip(
                                  icon: role.icon,
                                  label: role.label(l10n),
                                  onTap: _submitting
                                      ? null
                                      : () => _quickLogin(email),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            [
                              for (final (role, email) in _demoAccounts)
                                '${role.label(l10n)}: $email',
                              '${l10n.password}: $_demoPassword',
                            ].join('\n'),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
