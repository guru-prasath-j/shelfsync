import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog_repository.dart';
import 'catalog_widgets.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));
    return Scaffold(
      appBar: AppBar(),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This product isn\'t saved on your phone yet. '
                  'Connect to the internet to load it.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(productProvider(productId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(p.imageUrl),
              ),
            ),
            const SizedBox(height: 16),
            Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
            Text(p.unit, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            PriceTag(product: p),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: CartButton(product: p)),
          ],
        ),
      ),
    );
  }
}
