import 'package:flutter/material.dart';

enum BlockSchedule { live, scheduled, expired, unsupported }

/// Display helpers for raw CMS block JSON in the admin screens.
class BlockInfo {
  const BlockInfo._();

  static const known = {'notice', 'banner', 'carousel', 'product_grid'};
  static const addable = ['notice', 'banner', 'product_grid'];

  static String label(String type) => switch (type) {
        'notice' => 'Store notice',
        'banner' => 'Offer banner',
        'carousel' => 'Category row',
        'product_grid' => 'Product grid',
        _ => 'Unknown block ($type)',
      };

  static String hint(String type) => switch (type) {
        'notice' => 'One line of text, e.g. store timings',
        'banner' => 'Big image with a title and "Shop now"',
        'product_grid' => 'A titled grid of products you pick',
        _ => '',
      };

  static IconData icon(String type) => switch (type) {
        'notice' => Icons.campaign_outlined,
        'banner' => Icons.image_outlined,
        'carousel' => Icons.view_carousel_outlined,
        'product_grid' => Icons.grid_view,
        _ => Icons.help_outline,
      };

  static Map<String, dynamic> data(Map<String, dynamic> block) =>
      (block['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

  static String summary(Map<String, dynamic> block) {
    final d = data(block);
    String s(String key) => (d[key] as String? ?? '').trim();
    final text = switch (block['type']) {
      'notice' => s('text'),
      'banner' => s('title'),
      'carousel' =>
        '${s('title')} · ${(d['items'] as List?)?.length ?? 0} items',
      'product_grid' =>
        '${s('title')} · ${(d['productIds'] as List?)?.length ?? 0} products',
      _ => block['id'] as String? ?? '',
    };
    return text.isEmpty ? '(no title)' : text;
  }

  static DateTime? startsAt(Map<String, dynamic> b) =>
      DateTime.tryParse(b['startsAt'] as String? ?? '');
  static DateTime? endsAt(Map<String, dynamic> b) =>
      DateTime.tryParse(b['endsAt'] as String? ?? '');

  /// Same rule the shopper app uses to decide what to show.
  static BlockSchedule schedule(Map<String, dynamic> block, DateTime now) {
    if (!known.contains(block['type'])) return BlockSchedule.unsupported;
    final start = startsAt(block);
    final end = endsAt(block);
    if (start != null && now.isBefore(start)) return BlockSchedule.scheduled;
    if (end != null && now.isAfter(end)) return BlockSchedule.expired;
    return BlockSchedule.live;
  }

  /// A new, empty block with an id that doesn't clash with existing ones.
  static Map<String, dynamic> blank(
    String type, {
    required Iterable<Object?> existingIds,
  }) {
    final taken = existingIds.toSet();
    final base =
        '${type.replaceAll('_', '-')}-${DateTime.now().millisecondsSinceEpoch}';
    var id = base;
    for (var n = 2; taken.contains(id); n++) {
      id = '$base-$n';
    }
    return {
      'id': id,
      'type': type,
      'data': switch (type) {
        'notice' => {'text': ''},
        'banner' => {
            'title': '',
            'subtitle': '',
            'imageUrl': '',
            'deeplink': null,
          },
        'product_grid' => {'title': '', 'productIds': <String>[]},
        _ => <String, dynamic>{},
      },
    };
  }
}
