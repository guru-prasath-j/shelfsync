import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/presentation/catalog_widgets.dart';
import '../data/cart_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final lines = cart.lines.values.toList();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: lines.isEmpty
          ? const Center(child: Text('Your cart is empty. Add items from the store.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lines.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, i) {
                final line = lines[i];
                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox.square(
                        dimension: 56,
                        child: AppImage(line.product.imageUrl),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.product.name, style: text.titleSmall),
                          Text('₹${line.total}', style: text.bodyMedium),
                        ],
                      ),
                    ),
                    CartButton(product: line.product),
                  ],
                );
              },
            ),
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cart.pendingChanges > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.sync, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cart.isSyncing
                                    ? 'Saving your changes…'
                                    : '${cart.pendingChanges} change(s) will save when you\'re back online.',
                                style: text.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Total ₹${cart.total}', style: text.titleLarge),
                        ),
                        FilledButton(
                          onPressed: cart.pendingChanges > 0 ? null : () {},
                          child: const Text('Checkout'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
