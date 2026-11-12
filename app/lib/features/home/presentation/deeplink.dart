import 'package:flutter/material.dart';

import '../../catalog/presentation/product_detail_screen.dart';

/// CMS content links to app screens with simple paths like `product/p2`.
void openDeeplink(BuildContext context, String? link) {
  if (link == null || link.isEmpty) return;
  final parts = link.split('/');
  if (parts.length == 2 && parts.first == 'product') {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(productId: parts[1]),
      ),
    );
  }
  // Unknown links are ignored, same as unknown block types.
}
