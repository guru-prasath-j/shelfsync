import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode.dart';
import '../../admin/presentation/admin_login_screen.dart';
import '../../cart/data/cart_providers.dart';
import '../../cart/presentation/cart_bar.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../../catalog/presentation/search_screen.dart';
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

    return Scaffold(
      bottomNavigationBar: const CartBar(),
      body: layout.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const CustomScrollView(
          slivers: [
            _HomeHeader(),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (_, __) => CustomScrollView(
          slivers: [
            const _HomeHeader(),
            SliverFillRemaining(
              hasScrollBody: false,
              child: StatusMessage(
                icon: Icons.wifi_off_outlined,
                title: 'You\'re offline',
                message: 'Connect to the internet once to load the store. '
                    'After that, it works even without a connection.',
                actionLabel: 'Try again',
                onAction: () => _refresh(ref),
              ),
            ),
          ],
        ),
        data: (result) {
          final blocks = result.layout.visibleBlocks(DateTime.now());
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const _HomeHeader(),
                if (result.isStale)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                    sliver: SliverToBoxAdapter(child: _StaleNote()),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.lg,
                    Gap.lg,
                    Gap.xl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: blocks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.xl),
                    itemBuilder: (_, i) => buildBlock(blocks[i]),
                  ),
                ),
                const SliverToBoxAdapter(child: _Footer()),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// White header with the store name, cart shortcut and a search box that
/// stays pinned while the page scrolls.
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(cartProvider.select((c) => c.itemCount));
    final offline = ref.watch(
      connectivityProvider.select(
        (c) =>
            c.valueOrNull?.every((r) => r == ConnectivityResult.none) ?? false,
      ),
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      pinned: true,
      toolbarHeight: 64,
      titleSpacing: Gap.lg,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.leaf,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 22),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ShelfSync', style: text.titleLarge),
                Row(
                  children: [
                    Icon(
                      offline ? Icons.cloud_off : Icons.storefront,
                      size: 13,
                      color: offline
                          ? context.palette.danger
                          : context.palette.accent,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        offline
                            ? 'Offline · showing saved store'
                            : 'Fresh groceries, everyday prices',
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Light or dark theme',
          onPressed: () => showThemePicker(context, ref),
          icon: Icon(themeModeIcon(ref.watch(themeModeProvider))),
        ),
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
          child: Material(
            color: Theme.of(context).inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(Radii.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              ),
              child: SizedBox(
                height: 46,
                child: Row(
                  children: [
                    const SizedBox(width: Gap.md),
                    Icon(Icons.search, color: scheme.onSurfaceVariant),
                    const SizedBox(width: Gap.sm),
                    Text(
                      'Search milk, atta, fruits…',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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

class _StaleNote extends StatelessWidget {
  const _StaleNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'Showing saved offers. Pull down to check for updates.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget point(IconData icon, String label) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: context.palette.accent),
              const SizedBox(height: Gap.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: muted),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Column(
        children: [
          Row(
            children: [
              point(Icons.sell_outlined, 'Live prices\n& offers'),
              point(Icons.sync, 'Cart syncs\nautomatically'),
              point(Icons.wifi_off_outlined, 'Works even\noffline'),
            ],
          ),
          const SizedBox(height: Gap.lg),
          // Quiet link for store staff; shoppers don't need it.
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: muted),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminLoginScreen()),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: const Text('Store admin'),
          ),
        ],
      ),
    );
  }
}
