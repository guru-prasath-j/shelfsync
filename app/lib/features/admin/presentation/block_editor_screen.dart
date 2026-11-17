import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/product.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import 'block_info.dart';

class BlockEditResult {
  const BlockEditResult.saved(Map<String, dynamic> this.block)
      : deleted = false;
  const BlockEditResult.deleted()
      : block = null,
        deleted = true;
  final Map<String, dynamic>? block;
  final bool deleted;
}

/// Form for one block. Edits a deep copy, so Cancel leaves the list as it was.
class BlockEditorScreen extends ConsumerStatefulWidget {
  const BlockEditorScreen({super.key, required this.block, this.isNew = false});
  final Map<String, dynamic> block;
  final bool isNew;

  @override
  ConsumerState<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends ConsumerState<BlockEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> _block =
      (jsonDecode(jsonEncode(widget.block)) as Map).cast<String, dynamic>();
  late final Map<String, dynamic> _data = BlockInfo.data(_block);
  late final Map<String, TextEditingController> _fields = {
    for (final key in const ['text', 'title', 'subtitle', 'imageUrl'])
      key: TextEditingController(text: _data[key] as String? ?? ''),
  };
  late DateTime? _start = BlockInfo.startsAt(_block)?.toLocal();
  late DateTime? _end = BlockInfo.endsAt(_block)?.toLocal();
  late List<String> _productIds = [
    ...(_data['productIds'] as List? ?? const []).whereType<String>(),
  ];
  String? _productError;

  String get _type => _block['type'] as String? ?? '';
  bool get _editable => BlockInfo.known.contains(_type);

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final validForm = _form.currentState?.validate() ?? true;
    setState(() {
      _productError = _type == 'product_grid' && _productIds.isEmpty
          ? 'Pick at least one product'
          : null;
    });
    if (!validForm || _productError != null) return;

    String f(String key) => _fields[key]!.text.trim();
    switch (_type) {
      case 'notice':
        _data['text'] = f('text');
      case 'banner':
        _data['title'] = f('title');
        _data['subtitle'] = f('subtitle');
        _data['imageUrl'] = f('imageUrl');
      case 'carousel':
        _data['title'] = f('title');
      case 'product_grid':
        _data['title'] = f('title');
        _data['productIds'] = _productIds;
        _data.remove('products'); // the server fills these in
    }
    _block['data'] = _data;
    _setDate('startsAt', _start);
    _setDate('endsAt', _end);
    Navigator.pop(context, BlockEditResult.saved(_block));
  }

  void _setDate(String key, DateTime? value) {
    if (value == null) {
      _block.remove(key);
    } else {
      _block[key] = value.toUtc().toIso8601String();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this block?'),
        content: const Text(
          'It disappears from the home screen after you publish.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.tomato),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, const BlockEditResult.deleted());
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = (start ? _start : _end) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: start ? 'Show from' : 'Show until',
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = DateTime(picked.year, picked.month, picked.day);
      } else {
        // Whole last day counts.
        _end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew
              ? 'New ${BlockInfo.label(_type).toLowerCase()}'
              : BlockInfo.label(_type),
        ),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: 'Delete block',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          const SizedBox(width: Gap.xs),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _editable ? _save : null,
              child: Text(widget.isNew ? 'Add block' : 'Save changes'),
            ),
          ),
        ),
      ),
      body: !_editable
          ? StatusMessage(
              icon: Icons.help_outline,
              title: 'This app can\'t edit "$_type" blocks',
              message: 'It\'s kept as is when you publish. You can delete it '
                  'here or edit it on the web admin page.',
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(Gap.lg),
                children: [
                  ..._fieldsFor(_type),
                  const SizedBox(height: Gap.xl),
                  Text('When to show', style: text.titleMedium),
                  const SizedBox(height: Gap.xs),
                  Text(
                    'Leave empty to show it all the time.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: Gap.sm),
                  _DateRow(
                    label: 'Show from',
                    value: _start,
                    onPick: () => _pickDate(start: true),
                    onClear: () => setState(() => _start = null),
                  ),
                  _DateRow(
                    label: 'Show until',
                    value: _end,
                    onPick: () => _pickDate(start: false),
                    onClear: () => setState(() => _end = null),
                  ),
                  if (_start != null && _end != null && _end!.isBefore(_start!))
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.xs),
                      child: Text(
                        '"Show until" is before "Show from", so this block will never appear.',
                        style: text.bodySmall
                            ?.copyWith(color: context.palette.danger),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  List<Widget> _fieldsFor(String type) {
    String? required(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
    TextFormField field(
      String key,
      String label, {
      String? hint,
      int maxLines = 1,
      String? Function(String?)? validator,
      TextInputType? keyboard,
    }) =>
        TextFormField(
          controller: _fields[key],
          maxLines: maxLines,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: validator,
        );
    const gap = SizedBox(height: Gap.md);

    return switch (type) {
      'notice' => [
          field(
            'text',
            'Notice text',
            hint: 'e.g. Store open till 11 pm this week',
            maxLines: 3,
            validator: required,
          ),
        ],
      'banner' => [
          field(
            'title',
            'Title',
            hint: 'e.g. Weekend staples sale',
            validator: required,
          ),
          gap,
          field(
            'subtitle',
            'Subtitle (optional)',
            hint: 'e.g. Up to 20% off on atta',
          ),
          gap,
          field(
            'imageUrl',
            'Image link (optional)',
            hint: 'https://… or /images/banner-rice.jpg',
            keyboard: TextInputType.url,
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return null;
              // Photos stored on the CMS itself.
              if (RegExp(r'^/images/[\w.-]+$').hasMatch(s)) return null;
              final uri = Uri.tryParse(s);
              return uri != null && uri.hasScheme && uri.host.isNotEmpty
                  ? null
                  : 'Enter https://… or /images/<file> from the CMS';
            },
          ),
          gap,
          _BannerLinkPicker(
            value: _data['deeplink'] as String?,
            onChanged: (v) => setState(() => _data['deeplink'] = v),
          ),
        ],
      'carousel' => [
          field('title', 'Row title', validator: required),
          gap,
          Text(
            '${(_data['items'] as List?)?.length ?? 0} category tiles. '
            'Edit the tiles themselves on the web admin page.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      'product_grid' => [
          field(
            'title',
            'Section title',
            hint: 'e.g. Daily essentials',
            validator: required,
          ),
          gap,
          _ProductPicker(
            selected: _productIds,
            error: _productError,
            onChanged: (ids) => setState(() {
              _productIds = ids;
              _productError = null;
            }),
          ),
        ],
      _ => const [],
    };
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final shown = v == null
        ? 'Any time'
        : '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(shown),
      onTap: onPick,
      trailing: v == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: 'Clear date',
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
    );
  }
}

/// "Shop now" target: none, or one product page.
class _BannerLinkPicker extends ConsumerWidget {
  const _BannerLinkPicker({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products =
        ref.watch(allProductsProvider).valueOrNull ?? const <Product>[];
    final options = <String?, String>{
      null: 'No link (no "Shop now" button)',
      for (final p in products) 'product/${p.id}': '${p.name} (${p.unit})',
    };
    // Keep a link the app doesn't recognise rather than silently dropping it.
    if (value != null && !options.containsKey(value)) options[value] = value!;
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '"Shop now" opens'),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ProductPicker extends ConsumerWidget {
  const _ProductPicker({
    required this.selected,
    required this.onChanged,
    this.error,
  });
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final products = ref.watch(allProductsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Products (${selected.length} picked)', style: text.titleMedium),
        if (error != null)
          Text(
            error!,
            style: text.bodySmall?.copyWith(color: context.palette.danger),
          ),
        const SizedBox(height: Gap.xs),
        products.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Text('Couldn\'t load products.'),
          data: (all) => Card(
            child: Column(
              children: [
                for (final p in all)
                  CheckboxListTile(
                    value: selected.contains(p.id),
                    onChanged: (on) => onChanged(
                      on == true
                          ? [...selected, p.id]
                          : selected.where((id) => id != p.id).toList(),
                    ),
                    secondary: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: SizedBox.square(
                        dimension: 40,
                        child: AppImage(p.imageUrl),
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.unit} · ₹${p.price}'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
