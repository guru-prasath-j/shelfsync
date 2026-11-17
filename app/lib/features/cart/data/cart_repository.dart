import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/storage/key_value_store.dart';
import '../../catalog/domain/product.dart';
import '../domain/cart_models.dart';

/// Local source of truth for the cart plus an outbox of unsynced changes.
/// The UI updates instantly from here; [CartSyncService] drains the outbox.
class CartRepository {
  CartRepository(
    this._store, {
    String Function()? newId,
    DateTime Function()? clock,
  })  : _newId = newId ?? const Uuid().v4,
        _clock = clock ?? DateTime.now;

  final KeyValueStore _store;
  final String Function() _newId;
  final DateTime Function() _clock;

  static const _linesKey = 'cart:lines';
  static const _outboxKey = 'cart:outbox';

  Map<String, CartLine> lines() {
    final raw = _store.read(_linesKey);
    if (raw == null) return {};
    final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return map.map(
      (k, v) =>
          MapEntry(k, CartLine.fromJson((v as Map).cast<String, dynamic>())),
    );
  }

  List<CartOp> pendingOps() {
    final raw = _store.read(_outboxKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => CartOp.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> setQty(Product product, int qty) async {
    final current = lines();
    if (qty <= 0) {
      current.remove(product.id);
    } else {
      current[product.id] = CartLine(product: product, qty: qty);
    }
    await _store.write(
      _linesKey,
      jsonEncode(current.map((k, v) => MapEntry(k, v.toJson()))),
    );

    // Coalesce: tapping + five times offline sends one op, not five.
    final outbox = pendingOps()
      ..removeWhere((op) => op.productId == product.id);
    outbox.add(
      CartOp(
        opId: _newId(),
        productId: product.id,
        qty: qty < 0 ? 0 : qty,
        at: _clock().millisecondsSinceEpoch,
      ),
    );
    await _saveOutbox(outbox);
  }

  Future<void> removeAcknowledged(Set<String> opIds) async {
    final outbox = pendingOps()..removeWhere((op) => opIds.contains(op.opId));
    await _saveOutbox(outbox);
  }

  Future<void> _saveOutbox(List<CartOp> ops) => _store.write(
        _outboxKey,
        jsonEncode(ops.map((o) => o.toJson()).toList()),
      );
}
