import 'package:flutter_test/flutter_test.dart';
import 'package:shelfsync/features/home/domain/layout_block.dart';

void main() {
  test('parses known block types and keeps unknown ones as UnknownBlock', () {
    final layout = HomeLayout.fromJson({
      'schemaVersion': 1,
      'blocks': [
        {'id': 'n', 'type': 'notice', 'data': {'text': 'Open till 11'}},
        {
          'id': 'g',
          'type': 'product_grid',
          'data': {
            'title': 'Daily',
            'products': [
              {'id': 'p1', 'name': 'Milk', 'unit': '500 ml', 'price': 27, 'mrp': 28},
            ],
          },
        },
        {'id': 'x', 'type': 'video_reel', 'data': {}},
      ],
    });

    expect(layout.blocks[0], isA<NoticeBlock>());
    expect((layout.blocks[1] as ProductGridBlock).products.single.savings, 1);
    expect(layout.blocks[2], isA<UnknownBlock>());
    expect(layout.visibleBlocks(DateTime.utc(2026, 11, 12)), hasLength(2));
  });

  test('scheduled blocks only show inside their window', () {
    final block = LayoutBlock.fromJson({
      'id': 'b',
      'type': 'banner',
      'startsAt': '2026-10-01T00:00:00Z',
      'endsAt': '2026-10-31T23:59:59Z',
      'data': {'title': 'Diwali sweets'},
    });

    expect(block.isVisibleAt(DateTime.utc(2026, 9, 30)), isFalse);
    expect(block.isVisibleAt(DateTime.utc(2026, 10, 15)), isTrue);
    expect(block.isVisibleAt(DateTime.utc(2026, 11, 1)), isFalse);
  });

  test('missing fields fall back to safe defaults', () {
    final block = LayoutBlock.fromJson({'type': 'banner'}) as BannerBlock;
    expect(block.title, isEmpty);
    expect(block.imageUrl, isEmpty);
    expect(block.deeplink, isNull);
  });
}
