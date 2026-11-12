import '../../catalog/domain/product.dart';

class CartLine {
  const CartLine({required this.product, required this.qty});

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        product: Product.fromJson(
          (json['product'] as Map).cast<String, dynamic>(),
        ),
        qty: (json['qty'] as num).toInt(),
      );

  /// Snapshot of the product when it was added, so the cart renders offline.
  final Product product;
  final int qty;

  int get total => product.price * qty;

  Map<String, dynamic> toJson() => {'product': product.toJson(), 'qty': qty};
}

/// A queued change waiting for the server. "set qty" (not "add 1") makes
/// replays harmless: applying the same op twice gives the same result.
class CartOp {
  const CartOp({
    required this.opId,
    required this.productId,
    required this.qty,
    required this.at,
  });

  factory CartOp.fromJson(Map<String, dynamic> json) => CartOp(
        opId: json['opId'] as String,
        productId: json['productId'] as String,
        qty: (json['qty'] as num).toInt(),
        at: (json['at'] as num).toInt(),
      );

  final String opId;
  final String productId;
  final int qty;

  /// Client timestamp (ms) for last-write-wins on the server.
  final int at;

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'type': 'set',
        'productId': productId,
        'qty': qty,
        'at': at,
      };
}

class CartState {
  const CartState({
    this.lines = const {},
    this.pendingChanges = 0,
    this.isSyncing = false,
  });

  final Map<String, CartLine> lines;
  final int pendingChanges;
  final bool isSyncing;

  int qtyOf(String productId) => lines[productId]?.qty ?? 0;
  int get itemCount => lines.values.fold(0, (sum, l) => sum + l.qty);
  int get total => lines.values.fold(0, (sum, l) => sum + l.total);
}
