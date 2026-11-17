import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../cart/data/cart_providers.dart';
import '../../cart/presentation/cart_screen.dart';
import '../data/catalog_repository.dart';
import '../domain/product.dart';
import 'catalog_widgets.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));
    final itemCount = ref.watch(cartProvider.select((c) => c.itemCount));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
            icon: Badge(
              isLabelVisible: itemCount > 0,
              backgroundColor: AppColors.tomato,
              label: Text('$itemCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      bottomNavigationBar: product.valueOrNull == null
          ? null
          : _BuyBar(product: product.requireValue),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => StatusMessage(
          icon: Icons.wifi_off_outlined,
          title: 'Product not saved yet',
          message: 'This product isn\'t on your phone yet. '
              'Connect to the internet to load it.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(productProvider(productId)),
        ),
        data: (p) => _Details(product: p),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        Container(
          color: scheme.surface,
          padding: const EdgeInsets.all(Gap.lg),
          child: AspectRatio(
            aspectRatio: 1.1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: AppImage(product.imageUrl),
                ),
                Positioned(
                  top: Gap.md,
                  left: Gap.md,
                  child: DiscountBadge(product: product),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: scheme.surface,
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.name, style: text.headlineSmall),
              const SizedBox(height: Gap.xs),
              Text(
                product.unit,
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: Gap.md),
              PriceTag(product: product, large: true),
              Text(
                '(Inclusive of all taxes)',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: Gap.md),
              _StockChip(inStock: product.inStock),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        Container(
          color: scheme.surface,
          padding: const EdgeInsets.all(Gap.lg),
          child: const Column(
            children: [
              _Assurance(
                icon: Icons.sell_outlined,
                title: 'Live store prices',
                subtitle: 'Prices and offers update straight from the store.',
              ),
              SizedBox(height: Gap.md),
              _Assurance(
                icon: Icons.cloud_done_outlined,
                title: 'Add to cart even offline',
                subtitle:
                    'Your cart saves automatically when you\'re back online.',
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.inStock});
  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final color = inStock ? context.palette.accent : context.palette.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock ? Icons.check_circle : Icons.remove_circle,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            inStock ? 'In stock' : 'Out of stock',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Assurance extends StatelessWidget {
  const _Assurance({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(Gap.sm),
          decoration: BoxDecoration(
            color: context.palette.accentSoft,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Icon(icon, color: context.palette.accent, size: 20),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      '₹${product.price}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      product.unit,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: CartButton(product: product, expanded: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
