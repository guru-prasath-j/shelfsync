import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../data/admin_api.dart';
import 'admin_dashboard_screen.dart';

final _adminStatusProvider = FutureProvider.autoDispose<AdminStatus>(
  (ref) => ref.watch(adminApiProvider).status(),
);

/// Entry point for store staff: first-time password setup or login.
class AdminLoginScreen extends ConsumerWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_adminStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Store admin')),
      body: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => StatusMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Can\'t reach the store server',
          message: e is AdminException
              ? e.message
              : 'Admin needs a connection to the CMS.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(_adminStatusProvider),
        ),
        data: (s) {
          if (!s.passwordSet && !s.canSetup) {
            return const StatusMessage(
              icon: Icons.usb,
              title: 'Admin isn\'t set up yet',
              message: 'Create the first admin password from the PC running '
                  'the CMS, or from a phone connected to it by USB.',
            );
          }
          return _PasswordForm(setup: !s.passwordSet);
        },
      ),
    );
  }
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm({required this.setup});
  final bool setup;

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(adminApiProvider);
    try {
      final token = widget.setup
          ? await api.setup(_password.text)
          : await api.login(_password.text);
      ref.read(adminSessionProvider.notifier).signIn(token);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AdminDashboardScreen()),
      );
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: const EdgeInsets.all(Gap.xl),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(Gap.lg + 4),
            decoration: BoxDecoration(
              color: context.palette.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.setup ? Icons.lock_reset : Icons.admin_panel_settings,
              size: 40,
              color: context.palette.accent,
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text(
          widget.setup ? 'Create admin password' : 'Admin login',
          textAlign: TextAlign.center,
          style: text.titleLarge,
        ),
        const SizedBox(height: Gap.xs),
        Text(
          widget.setup
              ? 'First time setup. Pick a password only store staff know. '
                  'You\'ll use it here and on the web admin page.'
              : 'Enter the store admin password to edit the home screen.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: Gap.xl),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofocus: true,
                  autofillHints: [
                    widget.setup
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  textInputAction: widget.setup
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: widget.setup ? null : (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v ?? '').length < 8 ? 'At least 8 characters' : null,
                ),
                if (widget.setup) ...[
                  const SizedBox(height: Gap.md),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        v != _password.text ? 'Passwords don\'t match' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Gap.md),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: context.palette.danger),
          ),
        ],
        const SizedBox(height: Gap.xl),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.setup ? 'Create password' : 'Log in'),
          ),
        ),
      ],
    );
  }
}
