import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../cart/data/cart_providers.dart';
import '../domain/product.dart';

/// Disk-cached image with a calm placeholder, so cached screens look
/// complete offline and tests never hit the network for an empty URL.
class AppImage extends StatelessWidget {
  const AppImage(this.url, {super.key, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined)),
    );
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text('₹${product.price}', style: text.titleMedium),
        if (product.savings > 0) ...[
          Text(
            '₹${product.mrp}',
            style: text.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Save ₹${product.savings}',
            style: text.labelMedium?.copyWith(color: AppColors.tomato),
          ),
        ],
      ],
    );
  }
}

/// "Add" button that turns into a − qty + stepper. Writes go to the local
/// cart first, so it works the same online and offline.
class CartButton extends ConsumerWidget {
  const CartButton({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) => c.qtyOf(product.id)));
    final cart = ref.read(cartProvider.notifier);

    if (!product.inStock) {
      return const OutlinedButton(onPressed: null, child: Text('Out of stock'));
    }
    if (qty == 0) {
      return FilledButton(
        onPressed: () => cart.setQty(product, 1),
        child: const Text('Add'),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Remove one',
          onPressed: () => cart.setQty(product, qty - 1),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Add one',
          onPressed: () => cart.setQty(product, qty + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});
  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card.outlined(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(product.imageUrl),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall,
              ),
              Text(product.unit, style: text.bodySmall),
              const Spacer(),
              PriceTag(product: product),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: CartButton(product: product),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
