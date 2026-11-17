import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../domain/product.dart';

class CatalogRepository {
  CatalogRepository(this._api);
  final ApiClient _api;

  /// Network first (ETag makes an unchanged product a cheap 304), falling
  /// back to the last cached copy when offline.
  Future<Product> product(String id) async {
    final path = 'products/$id';
    try {
      return Product.fromJson(await _api.getJson(path) as Map<String, dynamic>);
    } catch (_) {
      final cached = _api.cachedJson(path);
      if (cached is Map<String, dynamic>) return Product.fromJson(cached);
      rethrow;
    }
  }

  /// Whole catalogue for search; same network-first, cache-fallback rule.
  Future<List<Product>> all() async {
    const path = 'products';
    List<Product> parse(Object? json) => (json as List)
        .map((e) => Product.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    try {
      return parse(await _api.getJson(path));
    } catch (_) {
      final cached = _api.cachedJson(path);
      if (cached is List) return parse(cached);
      rethrow;
    }
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(apiClientProvider)),
);

final allProductsProvider = FutureProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(catalogRepositoryProvider).all(),
);

final productProvider = FutureProvider.autoDispose.family<Product, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).product(id),
);
