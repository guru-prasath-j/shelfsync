import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../cart/presentation/cart_bar.dart';
import '../../home/presentation/deeplink.dart';
import '../data/catalog_repository.dart';
import '../domain/product.dart';
import 'catalog_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Product> _filter(List<Product> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.unit.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(allProductsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Gap.lg),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search milk, atta, fruits…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CartBar(),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => StatusMessage(
          icon: Icons.wifi_off_outlined,
          title: 'Can\'t load products',
          message: 'Connect to the internet once to search the store.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(allProductsProvider),
        ),
        data: (all) {
          final results = _filter(all);
          if (results.isEmpty) {
            return StatusMessage(
              icon: Icons.search_off,
              title: 'No results for "$_query"',
              message: 'Try a different word, like "rice" or "milk".',
            );
          }
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    _query.isEmpty
                        ? 'All products (${results.length})'
                        : '${results.length} result${results.length == 1 ? '' : 's'}',
                    style: text.titleMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(Gap.lg),
                sliver: SliverGrid.builder(
                  gridDelegate: productGridDelegate,
                  itemCount: results.length,
                  itemBuilder: (context, i) => ProductCard(
                    product: results[i],
                    onTap: () =>
                        openDeeplink(context, 'product/${results[i].id}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Two columns on phones, more on wider layouts; shared by home and search.
const productGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 200,
  mainAxisExtent: 286,
  crossAxisSpacing: Gap.md,
  mainAxisSpacing: Gap.md,
);
