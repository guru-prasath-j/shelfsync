import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../catalog/domain/product.dart';
import '../domain/cart_models.dart';
import 'cart_repository.dart';
import 'cart_sync_service.dart';

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(cartStoreProvider)),
);

final cartSyncServiceProvider = Provider<CartSyncService>(
  (ref) => CartSyncService(
    ref.watch(cartRepositoryProvider),
    ref.watch(apiClientProvider),
  ),
);

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

class CartNotifier extends Notifier<CartState> {
  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  CartState build() {
    // Coming back online drains the outbox automatically.
    ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityProvider,
      (_, next) {
        final results = next.valueOrNull ?? const <ConnectivityResult>[];
        if (results.any((r) => r != ConnectivityResult.none)) {
          unawaited(sync());
        }
      },
    );
    final repo = ref.watch(cartRepositoryProvider);
    return CartState(
      lines: repo.lines(),
      pendingChanges: repo.pendingOps().length,
    );
  }

  Future<void> setQty(Product product, int qty) async {
    await _repo.setQty(product, qty);
    _reload();
    unawaited(sync());
  }

  Future<void> sync() async {
    if (state.isSyncing || state.pendingChanges == 0) return;
    state = CartState(
      lines: state.lines,
      pendingChanges: state.pendingChanges,
      isSyncing: true,
    );
    try {
      await ref.read(cartSyncServiceProvider).flush();
    } finally {
      _reload();
    }
  }

  void _reload() => state = CartState(
        lines: _repo.lines(),
        pendingChanges: _repo.pendingOps().length,
      );
}
