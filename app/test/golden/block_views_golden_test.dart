@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfsync/core/theme/app_theme.dart';
import 'package:shelfsync/features/home/domain/layout_block.dart';
import 'package:shelfsync/features/home/presentation/blocks/block_views.dart';

/// Locks the Figma-matched look of CMS blocks.
/// Generate/refresh the PNGs with: flutter test --update-goldens --tags golden
void main() {
  Widget frame(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );

  testWidgets('banner block', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 220));
    await tester.pumpWidget(
      frame(
        const BannerBlockView(
          block: BannerBlock(
            id: 'b',
            title: 'Weekend staples sale',
            subtitle: 'Up to 20% off on atta, rice and dals',
            imageUrl: '',
          ),
        ),
      ),
    );
    await expectLater(find.byType(BannerBlockView), matchesGoldenFile('goldens/banner_block.png'));
  });

  testWidgets('notice block', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 100));
    await tester.pumpWidget(
      frame(
        const NoticeBlockView(
          block: NoticeBlock(id: 'n', text: 'Koramangala store open till 11 pm this week.'),
        ),
      ),
    );
    await expectLater(find.byType(NoticeBlockView), matchesGoldenFile('goldens/notice_block.png'));
  });
}
