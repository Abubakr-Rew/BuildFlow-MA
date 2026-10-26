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

/// Registration screen — creates an owner account with a new company.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    // On success the router's redirect opens the director's home screen.
    await ref.read(authProvider.notifier).register(
          email: _emailController.text,
          password: _passwordController.text,
          name: _nameController.text,
          companyName: _companyController.text,
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
                    Text(
                      l10n.registerTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      l10n.createCompany,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),
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
                      label: l10n.companyName,
                      controller: _companyController,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.business_outlined,
                      validator: (v) => Validators.required(
                        v,
                        message: l10n.validationCompanyRequired,
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
                      label: l10n.registerButton,
                      onPressed: _submit,
                      isLoading: _submitting,
                      icon: Icons.person_add_rounded,
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
