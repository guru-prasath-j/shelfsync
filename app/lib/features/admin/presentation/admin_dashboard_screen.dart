import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../home/data/layout_repository.dart';
import '../data/admin_api.dart';
import 'admin_login_screen.dart';
import 'block_editor_screen.dart';
import 'block_info.dart';

/// Lets store staff rearrange, edit, add and remove home-screen blocks, then
/// publish. Works on the raw CMS JSON so fields this build doesn't know
/// about (and unknown block types) survive a publish untouched.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _layout; // everything except blocks (schemaVersion…)
  List<Map<String, dynamic>> _blocks = [];
  String _published = '';
  String? _loadError;
  bool _publishing = false;

  bool get _dirty => _layout != null && _encode() != _published;

  String _encode() => jsonEncode({..._layout!, 'blocks': _blocks});

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _token => ref.read(adminSessionProvider);

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final token = _token;
      if (token == null) return _backToLogin();
      final layout = await ref.read(adminApiProvider).fetchLayout(token);
      final blocks = (layout['blocks'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((b) => b.cast<String, dynamic>())
          .toList();
      setState(() {
        _layout = Map.of(layout)..remove('blocks');
        _blocks = blocks;
        _published = _encode();
      });
    } on AdminException catch (e) {
      if (e.sessionExpired) return _backToLogin();
      setState(() => _loadError = e.message);
    }
  }

  void _backToLogin() {
    ref.read(adminSessionProvider.notifier).signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AdminLoginScreen()),
    );
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.tomato : null,
        ),
      );
  }

  Future<void> _publish() async {
    final token = _token;
    if (token == null) return _backToLogin();
    setState(() => _publishing = true);
    try {
      final layout = {..._layout!, 'blocks': _blocks};
      await ref.read(adminApiProvider).publishLayout(token, layout);
      setState(() => _published = _encode());
      ref.invalidate(homeLayoutProvider); // our own home screen updates now
      _toast('Published. Shoppers see it on their next refresh.');
    } on AdminException catch (e) {
      if (e.sessionExpired) {
        _toast(
          'Session expired. Log in again — your edits were not published.',
          error: true,
        );
        return _backToLogin();
      }
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _edit(int index) async {
    final result = await Navigator.of(context).push<BlockEditResult>(
      MaterialPageRoute(
        builder: (_) => BlockEditorScreen(block: _blocks[index]),
      ),
    );
    if (result == null) return;
    setState(() {
      if (result.deleted) {
        _blocks.removeAt(index);
      } else {
        _blocks[index] = result.block!;
      }
    });
  }

  Future<void> _add() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Text(
                'Add a block',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final t in BlockInfo.addable)
              ListTile(
                leading: Icon(BlockInfo.icon(t), color: context.palette.accent),
                title: Text(BlockInfo.label(t)),
                subtitle: Text(BlockInfo.hint(t)),
                onTap: () => Navigator.pop(context, t),
              ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    final result = await Navigator.of(context).push<BlockEditResult>(
      MaterialPageRoute(
        builder: (_) => BlockEditorScreen(
          block:
              BlockInfo.blank(type, existingIds: _blocks.map((b) => b['id'])),
          isNew: true,
        ),
      ),
    );
    if (result?.block == null) return;
    setState(() => _blocks.insert(0, result!.block!));
    _toast('Added at the top. Drag to move it, then Publish.');
  }

  Future<void> _changePassword() async {
    final token = _token;
    if (token == null) return _backToLogin();
    final newToken = await showDialog<String>(
      context: context,
      builder: (_) => _ChangePasswordDialog(token: token),
    );
    if (newToken == null) return;
    ref.read(adminSessionProvider.notifier).signIn(newToken);
    _toast('Password changed. Other devices were logged out.');
  }

  Future<void> _logout() async {
    if (_dirty && !await _confirmDiscard()) return;
    final token = _token;
    if (token != null) await ref.read(adminApiProvider).logout(token);
    ref.read(adminSessionProvider.notifier).signOut();
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have changes that aren\'t published. Shoppers won\'t see them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _published = _encode()); // allow the pop
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home screen editor'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) => switch (v) {
                'reload' => _load(),
                'password' => _changePassword(),
                _ => _logout(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'reload',
                  child: Text('Reload from server'),
                ),
                PopupMenuItem(
                  value: 'password',
                  child: Text('Change password'),
                ),
                PopupMenuItem(value: 'logout', child: Text('Log out')),
              ],
            ),
          ],
        ),
        floatingActionButton: _layout == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add block'),
              ),
        bottomNavigationBar: _layout == null ? null : _publishBar(context),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loadError != null) {
      return StatusMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Couldn\'t load the layout',
        message: _loadError!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }
    if (_layout == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_blocks.isEmpty) {
      return const StatusMessage(
        icon: Icons.dashboard_customize_outlined,
        title: 'Home screen is empty',
        message:
            'Tap "Add block" to put an offer or notice on the home screen.',
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 96),
      buildDefaultDragHandles: false,
      header: Padding(
        padding: const EdgeInsets.only(bottom: Gap.md),
        child: Text(
          'Shoppers see these blocks top to bottom. Drag ≡ to reorder, tap to edit.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      itemCount: _blocks.length,
      onReorder: (from, to) => setState(() {
        if (to > from) to -= 1;
        _blocks.insert(to, _blocks.removeAt(from));
      }),
      itemBuilder: (context, i) => Padding(
        key: ValueKey(_blocks[i]['id']),
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: _BlockTile(
          block: _blocks[i],
          index: i,
          onTap: () => _edit(i),
        ),
      ),
    );
  }

  Widget _publishBar(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Icon(
                _dirty ? Icons.edit_note : Icons.cloud_done_outlined,
                color: _dirty ? context.palette.danger : context.palette.accent,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  _dirty ? 'Unpublished changes' : 'Everything is published',
                  style: text.bodyMedium,
                ),
              ),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: _dirty && !_publishing ? _publish : null,
                  icon: _publishing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.publish, size: 18),
                  label: const Text('Publish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.block,
    required this.index,
    required this.onTap,
  });
  final Map<String, dynamic> block;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final type = block['type'] as String? ?? '';
    final schedule = BlockInfo.schedule(block, DateTime.now());

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.xs, Gap.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Gap.sm),
                decoration: BoxDecoration(
                  color: context.palette.accentSoft,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child:
                    Icon(BlockInfo.icon(type), color: context.palette.accent),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      BlockInfo.summary(block),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          BlockInfo.label(type),
                          style: text.labelSmall?.copyWith(color: muted),
                        ),
                        _ScheduleChip(schedule: schedule),
                      ],
                    ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(Gap.sm),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.schedule});
  final BlockSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (schedule) {
      BlockSchedule.live => ('Live', context.palette.accent),
      BlockSchedule.scheduled => ('Scheduled', context.palette.warnIcon),
      BlockSchedule.expired => ('Expired · hidden', context.palette.danger),
      BlockSchedule.unsupported => ('Not shown in this app', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({required this.token});
  final String token;

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref.read(adminApiProvider).changePassword(
            widget.token,
            current: _current.text,
            next: _next.text,
          );
      if (mounted) Navigator.pop(context, token);
    } on AdminException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (v) =>
                  (v ?? '').length < 8 ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: Gap.md),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirm new password'),
              validator: (v) =>
                  v != _next.text ? 'Passwords don\'t match' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.md),
              Text(_error!, style: TextStyle(color: context.palette.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
