import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelfsync/features/cart/domain/cart_models.dart';
import 'package:shelfsync/features/catalog/domain/product.dart';
import 'package:shelfsync/features/checkout/data/checkout_api.dart';
import 'package:shelfsync/features/checkout/presentation/checkout_sheet.dart';

import 'support/fake_adapter.dart';

const _milk = Product(
  id: 'p1',
  name: 'Milk',
  unit: '500 ml',
  price: 27,
  mrp: 28,
  imageUrl: '',
  inStock: true,
);

void main() {
  test('sends only ids and quantities; the server sets the price', () async {
    final adapter = FakeAdapter(
      (o) => jsonBody(
        '{"orderId":"abcdef0123456789abcdef01","status":"created",'
        '"amount":5400,"payUrl":"http://cms/pay/abcdef0123456789abcdef01"}',
      ),
    );
    final api = CheckoutApi('http://cms/api/', adapter: adapter);

    final order = await api.createOrder(const [
      CartLine(product: _milk, qty: 2),
    ]);

    final sent = adapter.requests.single;
    expect(sent.path, 'checkout/orders');
    expect(jsonDecode(jsonEncode(sent.data)), {
      'lines': [
        {'productId': 'p1', 'qty': 2},
      ],
    });
    expect(order.amountPaise, 5400);
    expect(order.shortId, 'ABCDEF01');
    expect(order.isPaid, isFalse);
  });

  test('503 from the CMS means payments are not set up', () async {
    final api = CheckoutApi(
      'http://cms/api/',
      adapter: FakeAdapter(
        (o) => jsonBody(
          '{"error":"Online payment is not set up yet"}',
          status: 503,
        ),
      ),
    );
    await expectLater(
      api.createOrder(const [CartLine(product: _milk, qty: 1)]),
      throwsA(
        isA<CheckoutException>().having((e) => e.notConfigured, 'nc', true),
      ),
    );
  });

  test('a paid order is read back as paid', () async {
    final api = CheckoutApi(
      'http://cms/api/',
      adapter: FakeAdapter(
        (o) => jsonBody(
          '{"orderId":"abcdef0123456789abcdef01","status":"paid",'
          '"amount":2700,"paymentId":"pay_123"}',
        ),
      ),
    );
    final order = await api.status('abcdef0123456789abcdef01');
    expect(order.isPaid, isTrue);
    expect(order.paymentId, 'pay_123');
  });

  test('amounts show as rupees', () {
    expect(formatPaise(36500), '₹365');
    expect(formatPaise(2750), '₹27.50');
  });
}
