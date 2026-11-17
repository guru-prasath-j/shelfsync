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
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.local_grocery_store_outlined,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

/// "17% OFF" ribbon. Only shown when there is a real saving.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    if (product.discountPercent <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tomato,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${product.discountPercent}% OFF',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.product, this.large = false});
  final Product product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          '₹${product.price}',
          style: large ? text.headlineSmall : text.titleMedium,
        ),
        if (product.savings > 0)
          Text(
            '₹${product.mrp}',
            style: (large ? text.bodyLarge : text.bodySmall)?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        if (large && product.savings > 0)
          Text(
            'You save ₹${product.savings}',
            style: text.labelLarge?.copyWith(color: context.palette.danger),
          ),
      ],
    );
  }
}

/// "ADD" button that turns into a − qty + stepper. Writes go to the local
/// cart first, so it works the same online and offline.
class CartButton extends ConsumerWidget {
  const CartButton({super.key, required this.product, this.expanded = false});
  final Product product;

  /// Full-width version for the product page's bottom bar.
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) => c.qtyOf(product.id)));
    final cart = ref.read(cartProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final height = expanded ? 48.0 : 36.0;

    if (!product.inStock) {
      return SizedBox(
        height: height,
        width: expanded ? double.infinity : null,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(minimumSize: Size(0, height)),
          child: const Text('Out of stock'),
        ),
      );
    }

    if (qty == 0) {
      return SizedBox(
        height: height,
        width: expanded ? double.infinity : 84,
        child: OutlinedButton(
          onPressed: () => cart.setQty(product, 1),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, height),
            padding: EdgeInsets.zero,
            foregroundColor: context.palette.accent,
            backgroundColor: scheme.surface,
            side: BorderSide(color: context.palette.accent, width: 1.4),
          ),
          child: Text(expanded ? 'Add to cart' : 'ADD'),
        ),
      );
    }

    return Container(
      height: height,
      width: expanded ? double.infinity : 84,
      decoration: BoxDecoration(
        color: AppColors.leaf,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            tooltip: 'Remove one',
            onTap: () => cart.setQty(product, qty - 1),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Text(
                expanded ? '$qty in cart' : '$qty',
                key: ValueKey(qty),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: 'Add one',
            onTap: () => cart.setQty(product, qty + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: SizedBox(
          width: 28,
          height: double.infinity,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image takes whatever height the grid cell leaves, so cards
              // never overflow on narrow or wide phones.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: Opacity(
                        opacity: product.inStock ? 1 : 0.45,
                        child: AppImage(product.imageUrl),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: DiscountBadge(product: product),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.sm),
              SizedBox(
                height: 36, // always room for two lines, so rows align
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(height: 1.25),
                ),
              ),
              Text(
                product.unit,
                maxLines: 1,
                style: text.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: Gap.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${product.price}', style: text.titleMedium),
                        Text(
                          product.savings > 0 ? '₹${product.mrp}' : '',
                          style: text.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.xs),
                  CartButton(product: product),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple centred message used for empty and error states.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Gap.lg + 4),
              decoration: BoxDecoration(
                color: context.palette.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: context.palette.accent),
            ),
            const SizedBox(height: Gap.lg),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: Gap.xs + 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: Gap.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
