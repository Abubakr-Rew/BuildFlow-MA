import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/validators.dart';
import 'package:buildflow/core/widgets/app_logo.dart';
import 'package:buildflow/core/widgets/bf_button.dart';
import 'package:buildflow/core/widgets/bf_text_field.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Join screen — a foreman or worker signs up with the director's invite
/// code. The role and the company come from the code, not from the form.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    // On success the router's redirect opens the home screen of the role
    // the code was issued for.
    await ref.read(authProvider.notifier).joinWithInviteCode(
          inviteCode: _codeController.text,
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (mounted) setState(() => _submitting = false);
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
                    Text(l10n.joinTitle, style: theme.textTheme.headlineLarge),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      l10n.joinSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: context.bfTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),
                    BfTextField(
                      label: l10n.inviteCode,
                      hint: l10n.inviteCodeFieldHint,
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.vpn_key_outlined,
                      validator: (v) => Validators.required(
                        v,
                        message: l10n.validationInviteCodeRequired,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    BfTextField(
                      label: l10n.fullName,
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outlined,
                      validator: (v) => Validators.required(
                        v,
                        message: l10n.validationNameRequired,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
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
                          color: context.bfTheme.danger.fg,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacing24),
                    BfButton(
                      label: l10n.joinButton,
                      onPressed: _submit,
                      isLoading: _submitting,
                      icon: Icons.group_add_rounded,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.hasAccount,
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => context.go(Routes.login),
                          child: Text(l10n.loginButton),
                        ),
                      ],
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
