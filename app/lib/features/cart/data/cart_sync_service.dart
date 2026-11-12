import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'cart_repository.dart';

class CartSyncService {
  CartSyncService(this._repo, this._api);
  final CartRepository _repo;
  final ApiClient _api;

  /// Sends queued ops. Returns true when the outbox is empty afterwards.
  /// Only ops the server acknowledges are removed, so a request that dies
  /// halfway is simply retried later; the server ignores duplicate opIds.
  Future<bool> flush() async {
    final ops = _repo.pendingOps();
    if (ops.isEmpty) return true;
    try {
      final res = await _api.postJson('cart/ops', {
        'ops': ops.map((o) => o.toJson()).toList(),
      }) as Map<String, dynamic>;
      final applied = (res['applied'] as List? ?? const []).cast<String>().toSet();
      await _repo.removeAcknowledged(applied);
      return _repo.pendingOps().isEmpty;
    } on DioException {
      return false;
    }
  }
}
