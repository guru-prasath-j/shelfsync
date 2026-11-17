import '../../catalog/domain/product.dart';

/// One unit of server-driven UI. The CMS decides which blocks appear and in
/// what order; the app only knows how to draw each type.
sealed class LayoutBlock {
  const LayoutBlock({required this.id, this.startsAt, this.endsAt});

  factory LayoutBlock.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final startsAt = DateTime.tryParse(json['startsAt'] as String? ?? '');
    final endsAt = DateTime.tryParse(json['endsAt'] as String? ?? '');
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? const {};

    switch (json['type']) {
      case 'notice':
        return NoticeBlock(
          id: id,
          startsAt: startsAt,
          endsAt: endsAt,
          text: data['text'] as String? ?? '',
        );
      case 'banner':
        return BannerBlock(
          id: id,
          startsAt: startsAt,
          endsAt: endsAt,
          title: data['title'] as String? ?? '',
          subtitle: data['subtitle'] as String? ?? '',
          imageUrl: data['imageUrl'] as String? ?? '',
          deeplink: data['deeplink'] as String?,
        );
      case 'carousel':
        final items = (data['items'] as List? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => CarouselItem.fromJson(m.cast<String, dynamic>()))
            .toList();
        return CarouselBlock(
          id: id,
          startsAt: startsAt,
          endsAt: endsAt,
          title: data['title'] as String? ?? '',
          items: items,
        );
      case 'product_grid':
        final products = (data['products'] as List? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => Product.fromJson(m.cast<String, dynamic>()))
            .toList();
        return ProductGridBlock(
          id: id,
          startsAt: startsAt,
          endsAt: endsAt,
          title: data['title'] as String? ?? '',
          products: products,
        );
      default:
        // Forward compatibility: a block type this build doesn't know
        // (added in the CMS after release) is skipped, not a crash.
        return UnknownBlock(id: id, type: '${json['type']}');
    }
  }

  final String id;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Scheduled content: the CMS can publish a sale banner ahead of time.
  bool isVisibleAt(DateTime now) =>
      (startsAt == null || !now.isBefore(startsAt!)) &&
      (endsAt == null || !now.isAfter(endsAt!));
}

class NoticeBlock extends LayoutBlock {
  const NoticeBlock({
    required super.id,
    required this.text,
    super.startsAt,
    super.endsAt,
  });
  final String text;
}

class BannerBlock extends LayoutBlock {
  const BannerBlock({
    required super.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.deeplink,
    super.startsAt,
    super.endsAt,
  });
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? deeplink;
}

class CarouselItem {
  const CarouselItem({
    required this.title,
    required this.imageUrl,
    this.deeplink,
  });

  factory CarouselItem.fromJson(Map<String, dynamic> json) => CarouselItem(
        title: json['title'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        deeplink: json['deeplink'] as String?,
      );

  final String title;
  final String imageUrl;
  final String? deeplink;
}

class CarouselBlock extends LayoutBlock {
  const CarouselBlock({
    required super.id,
    required this.title,
    required this.items,
    super.startsAt,
    super.endsAt,
  });
  final String title;
  final List<CarouselItem> items;
}

class ProductGridBlock extends LayoutBlock {
  const ProductGridBlock({
    required super.id,
    required this.title,
    required this.products,
    super.startsAt,
    super.endsAt,
  });
  final String title;
  final List<Product> products;
}

class UnknownBlock extends LayoutBlock {
  const UnknownBlock({required super.id, required this.type});
  final String type;
}

class HomeLayout {
  const HomeLayout({required this.schemaVersion, required this.blocks});

  factory HomeLayout.fromJson(Map<String, dynamic> json) => HomeLayout(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        blocks: (json['blocks'] as List? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => LayoutBlock.fromJson(m.cast<String, dynamic>()))
            .toList(),
      );

  final int schemaVersion;
  final List<LayoutBlock> blocks;

  List<LayoutBlock> visibleBlocks(DateTime now) =>
      blocks.where((b) => b is! UnknownBlock && b.isVisibleAt(now)).toList();
}
