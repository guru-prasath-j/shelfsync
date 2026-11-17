import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelfsync/core/network/api_client.dart';
import 'package:shelfsync/core/storage/key_value_store.dart';
import 'package:shelfsync/features/cart/data/cart_repository.dart';
import 'package:shelfsync/features/cart/data/cart_sync_service.dart';
import 'package:shelfsync/features/catalog/domain/product.dart';

import 'support/fake_adapter.dart';

const _milk = Product(
  id: 'p1',
  name: 'Toned Milk',
  unit: '500 ml',
  price: 27,
  mrp: 28,
  imageUrl: '',
  inStock: true,
);

void main() {
  late CartRepository repo;
  late FakeAdapter adapter;
  late CartSyncService sync;
  var ids = 0;

  setUp(() {
    ids = 0;
    repo = CartRepository(
      MemoryStore(),
      newId: () => 'op${ids++}',
      clock: () => DateTime.fromMillisecondsSinceEpoch(1000 + ids),
    );
    adapter = FakeAdapter(offline);
    sync = CartSyncService(
      repo,
      ApiClient(
        baseUrl: 'http://cms.test/api/',
        cache: MemoryStore(),
        adapter: adapter,
      ),
    );
  });

  test('repeated changes to one product coalesce into a single op', () async {
    await repo.setQty(_milk, 1);
    await repo.setQty(_milk, 2);
    await repo.setQty(_milk, 3);

    expect(repo.lines()['p1']!.qty, 3);
    expect(repo.pendingOps().single.qty, 3);
  });

  test('offline flush keeps the outbox for a later retry', () async {
    await repo.setQty(_milk, 2);
    expect(await sync.flush(), isFalse);
    expect(repo.pendingOps(), hasLength(1));
  });

  test('online flush removes only acknowledged ops', () async {
    await repo.setQty(_milk, 2);
    final opId = repo.pendingOps().single.opId;
    adapter.respond = (o) {
      final body = o.data as Map<String, dynamic>;
      expect((body['ops'] as List).single['type'], 'set');
      return jsonBody(
        jsonEncode({
          'applied': [opId],
          'cart': {'p1': 2},
        }),
      );
    };

    expect(await sync.flush(), isTrue);
    expect(repo.pendingOps(), isEmpty);
    expect(repo.lines()['p1']!.qty, 2);
  });

  test('setting qty to 0 removes the line but still queues the change',
      () async {
    await repo.setQty(_milk, 1);
    await repo.setQty(_milk, 0);

    expect(repo.lines(), isEmpty);
    expect(repo.pendingOps().single.qty, 0);
  });
}
