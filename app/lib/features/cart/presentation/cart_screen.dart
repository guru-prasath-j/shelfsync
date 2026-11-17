import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../checkout/presentation/checkout_sheet.dart';
import '../data/cart_providers.dart';
import '../domain/cart_models.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove all items?'),
        content: const Text('Your cart will be emptied.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final cart = ref.read(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    for (final line in cart.lines.values.toList()) {
      await notifier.setQty(line.product, 0);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final lines = cart.lines.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lines.isEmpty ? 'Your cart' : 'Your cart (${cart.itemCount})',
        ),
        actions: [
          if (lines.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, ref),
              child: const Text('Clear'),
            ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: lines.isEmpty
          ? StatusMessage(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message: 'Add items from the store and they\'ll show up here.',
              actionLabel: 'Start shopping',
              onAction: () => Navigator.of(context).maybePop(),
            )
          : ListView(
              padding: const EdgeInsets.all(Gap.lg),
              children: [
                if (cart.pendingChanges > 0) ...[
                  _SyncNote(cart: cart),
                  const SizedBox(height: Gap.md),
                ],
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < lines.length; i++) ...[
                        if (i > 0)
                          const Divider(indent: Gap.lg, endIndent: Gap.lg),
                        _LineTile(line: lines[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),
                _BillSummary(cart: cart),
              ],
            ),
      bottomNavigationBar: lines.isEmpty ? null : _CheckoutBar(cart: cart),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final p = line.product;
    return Padding(
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: SizedBox.square(dimension: 64, child: AppImage(p.imageUrl)),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                Text(p.unit, style: text.bodySmall?.copyWith(color: muted)),
                const SizedBox(height: Gap.xs),
                Row(
                  children: [
                    Text('₹${line.total}', style: text.titleSmall),
                    if (p.savings > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '₹${p.mrp * line.qty}',
                        style: text.bodySmall?.copyWith(
                          color: muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          CartButton(product: p),
        ],
      ),
    );
  }
}

class _BillSummary extends StatelessWidget {
  const _BillSummary({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mrpTotal =
        cart.lines.values.fold<int>(0, (sum, l) => sum + l.product.mrp * l.qty);
    final discount = mrpTotal - cart.total;

    Widget row(String label, String value, {Color? color, bool bold = false}) {
      final style = bold ? text.titleMedium : text.bodyMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(value, style: style?.copyWith(color: color)),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill details', style: text.titleMedium),
            const SizedBox(height: Gap.sm),
            row('Item total (MRP)', '₹$mrpTotal'),
            if (discount > 0)
              row('Discount', '− ₹$discount', color: context.palette.accent),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Gap.sm),
              child: Divider(),
            ),
            row('To pay', '₹${cart.total}', bold: true),
            if (discount > 0) ...[
              const SizedBox(height: Gap.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.palette.accentSoft,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  'You\'re saving ₹$discount on this order',
                  textAlign: TextAlign.center,
                  style:
                      text.labelLarge?.copyWith(color: context.palette.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncNote extends StatelessWidget {
  const _SyncNote({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final n = cart.pendingChanges;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: context.palette.warnSoft,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          if (cart.isSyncing)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.cloud_upload_outlined, size: 20),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              cart.isSyncing
                  ? 'Saving your changes…'
                  : '$n change${n == 1 ? '' : 's'} will save when you\'re back online. '
                      'You can keep shopping.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.palette.onWarnSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart});
  final CartState cart;

  void _checkout(BuildContext context) =>
      showCheckoutSheet(context, cart.lines.values.toList());

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final waiting = cart.pendingChanges > 0;
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
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${cart.total}', style: text.titleLarge),
                    Text(
                      waiting ? 'Waiting to sync…' : 'Total to pay',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                height: 48,
                child: FilledButton(
                  // Checkout waits for the server to have the latest cart.
                  onPressed: waiting ? null : () => _checkout(context),
                  child: const Text('Proceed to checkout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
