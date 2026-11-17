import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfsync/core/network/api_client.dart';
import 'package:shelfsync/core/storage/key_value_store.dart';
import 'package:shelfsync/features/home/data/layout_repository.dart';

import 'support/fake_adapter.dart';

const _layout =
    '{"schemaVersion":1,"blocks":[{"id":"n","type":"notice","data":{"text":"Hi"}}]}';

void main() {
  late MemoryStore store;
  late FakeAdapter adapter;
  late ApiClient api;

  setUp(() {
    store = MemoryStore();
    adapter = FakeAdapter((_) => jsonBody(_layout, etag: '"v1"'));
    api = ApiClient(
      baseUrl: 'http://cms.test/api/',
      cache: store,
      adapter: adapter,
    );
  });

  test('sends If-None-Match and serves the cached body on 304', () async {
    await api.getJson('layout/home');

    adapter.respond = (o) {
      expect(o.headers['If-None-Match'], '"v1"');
      return ResponseBody.fromString('', 304);
    };
    final second = await api.dio.get<dynamic>('layout/home');

    expect(second.statusCode, 200);
    expect(second.extra['fromCache'], isTrue);
    expect((second.data as Map)['schemaVersion'], 1);
    expect(adapter.requests, hasLength(2));
  });

  test('layout stream: cached first, then fresh', () async {
    await api.getJson('layout/home'); // warm the cache
    final results = await LayoutRepository(api).watchHome().toList();

    expect(results, hasLength(2));
    expect(results.every((r) => !r.isStale), isTrue);
  });

  test('layout stream offline: falls back to cache and marks it stale',
      () async {
    await api.getJson('layout/home');
    adapter.respond = offline;

    final results = await LayoutRepository(api).watchHome().toList();

    expect(results.last.isStale, isTrue);
    expect(results.last.layout.blocks, hasLength(1));
  });

  test('layout stream offline with no cache: surfaces the error', () async {
    adapter.respond = offline;
    expect(LayoutRepository(api).watchHome().toList(), throwsA(anything));
  });
}
