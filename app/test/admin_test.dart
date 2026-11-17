import 'package:flutter_test/flutter_test.dart';
import 'package:shelfsync/features/admin/data/admin_api.dart';
import 'package:shelfsync/features/admin/presentation/block_info.dart';

import 'support/fake_adapter.dart';

void main() {
  group('AdminApi', () {
    test('sends the bearer token and returns the new one', () async {
      final adapter = FakeAdapter((o) => jsonBody('{"token":"t2"}'));
      final api = AdminApi('http://cms/api/', adapter: adapter);

      final token = await api.changePassword('t1', current: 'a', next: 'b');

      expect(token, 't2');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer t1');
      expect(adapter.requests.single.path, 'admin/password');
    });

    test('shows the server error message', () async {
      final api = AdminApi(
        'http://cms/api/',
        adapter: FakeAdapter(
          (o) => jsonBody('{"error":"Wrong password"}', status: 401),
        ),
      );
      await expectLater(
        api.login('x'),
        throwsA(
          isA<AdminException>()
              .having((e) => e.message, 'message', 'Wrong password')
              .having((e) => e.sessionExpired, 'sessionExpired', false),
        ),
      );
    });

    test('flags an expired session', () async {
      final api = AdminApi(
        'http://cms/api/',
        adapter: FakeAdapter(
          (o) => jsonBody('{"error":"Please log in again"}', status: 401),
        ),
      );
      await expectLater(
        api.fetchLayout('old'),
        throwsA(
          isA<AdminException>()
              .having((e) => e.sessionExpired, 'expired', true),
        ),
      );
    });

    test('offline gives a friendly message', () async {
      final api = AdminApi('http://cms/api/', adapter: FakeAdapter(offline));
      await expectLater(
        api.status(),
        throwsA(
          isA<AdminException>().having(
            (e) => e.message,
            'message',
            contains('Can\'t reach the store server'),
          ),
        ),
      );
    });
  });

  group('BlockInfo', () {
    final now = DateTime.utc(2026, 11, 17, 12);

    test('schedule matches what shoppers see', () {
      expect(BlockInfo.schedule({'type': 'banner'}, now), BlockSchedule.live);
      expect(
        BlockInfo.schedule(
          {'type': 'banner', 'startsAt': '2026-12-01T00:00:00Z'},
          now,
        ),
        BlockSchedule.scheduled,
      );
      expect(
        BlockInfo.schedule(
          {'type': 'banner', 'endsAt': '2026-10-31T23:59:59Z'},
          now,
        ),
        BlockSchedule.expired,
      );
      expect(
        BlockInfo.schedule({'type': 'video_reel'}, now),
        BlockSchedule.unsupported,
      );
    });

    test('new blocks get unique ids and the right empty data', () {
      final a = BlockInfo.blank('product_grid', existingIds: const []);
      final b = BlockInfo.blank('product_grid', existingIds: [a['id']]);
      expect(a['id'], isNot(b['id']));
      expect(a['type'], 'product_grid');
      expect(a['data'], {'title': '', 'productIds': <String>[]});
    });

    test('summary shows what the block says', () {
      expect(
        BlockInfo.summary({
          'type': 'product_grid',
          'data': {
            'title': 'Daily essentials',
            'productIds': ['p1', 'p2'],
          },
        }),
        'Daily essentials · 2 products',
      );
      expect(
        BlockInfo.summary({
          'type': 'notice',
          'data': {'text': ''},
        }),
        '(no title)',
      );
    });
  });
}
