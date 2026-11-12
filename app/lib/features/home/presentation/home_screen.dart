import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/data/cart_providers.dart';
import '../../cart/presentation/cart_screen.dart';
import '../data/layout_repository.dart';
import 'blocks/block_views.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeLayoutProvider);
    await ref.read(homeLayoutProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(homeLayoutProvider);
    final itemCount = ref.watch(cartProvider.select((c) => c.itemCount));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShelfSync'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
            icon: Badge(
              isLabelVisible: itemCount > 0,
              label: Text('$itemCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      body: layout.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _EmptyOffline(onRetry: () => _refresh(ref)),
        data: (result) {
          final blocks = result.layout.visibleBlocks(DateTime.now());
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: blocks.length + (result.isStale ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (context, i) {
                if (result.isStale && i == 0) return const _StaleNote();
                return buildBlock(blocks[result.isStale ? i - 1 : i]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _StaleNote extends StatelessWidget {
  const _StaleNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Showing saved offers. Pull down to check for updates.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _EmptyOffline extends StatelessWidget {
  const _EmptyOffline({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Connect to the internet once to load the store. '
              'After that, it works offline.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
