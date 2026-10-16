import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/feedback.dart';
import '../viewmodels/auth_view_model.dart';

/// Masuk (padanan frame `41 · Auth / Masuk` dan `63 · Mobile / Masuk`).
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authViewModelProvider.notifier).signIn(_email.text, _password.text);
  }

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty) {
      showMessage(context, 'Isi email dulu untuk reset password.', isError: true);
      return;
    }
    final ok = await ref.read(authViewModelProvider.notifier).resetPassword(_email.text);
    if (ok && mounted) showMessage(context, 'Link reset password dikirim ke email.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final state = ref.watch(authViewModelProvider);
    ref.listen(authViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                border: Border.all(color: tokens.line),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.lg,
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppRadius.tile),
                        ),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 26),
                      ),
                    ),
                    Column(
                      spacing: AppSpacing.xs,
                      children: [
                        Text(
                          'mPOS Distributor',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                        Text(
                          'Masuk untuk mengelola penjualan, pesanan, dan stok.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v ?? '').contains('@') ? null : 'Email tidak valid',
                    ),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').length >= 6 ? null : 'Minimal 6 karakter',
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _forgotPassword, child: const Text('Lupa password?')),
                    ),
                    FilledButton(
                      onPressed: state.isLoading ? null : _submit,
                      child: state.isLoading
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Masuk'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Daftar (distributor / pelanggan)'),
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
