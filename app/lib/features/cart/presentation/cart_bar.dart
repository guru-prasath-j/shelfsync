import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/cart_providers.dart';
import 'cart_screen.dart';

/// Sticky "3 items · ₹300  View cart" bar. Appears as soon as the cart has
/// something in it, so shoppers always know where checkout is.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider.select((c) => c.itemCount));
    final total = ref.watch(cartProvider.select((c) => c.total));
    final text = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: Material(
                  color: AppColors.leaf,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.md),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CartScreen(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: Gap.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(Gap.sm),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(Radii.sm),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$count item${count == 1 ? '' : 's'}',
                                  style: text.labelMedium?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '₹$total',
                                  style: text.titleMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'View cart',
                            style: text.titleSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white),
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
