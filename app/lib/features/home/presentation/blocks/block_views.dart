import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../catalog/presentation/catalog_widgets.dart';
import '../../domain/layout_block.dart';
import '../deeplink.dart';

/// The registry: one widget per block type. Adding a block type to the CMS
/// means adding one model, one case here and one widget.
Widget buildBlock(LayoutBlock block) => switch (block) {
      NoticeBlock notice => NoticeBlockView(block: notice),
      BannerBlock banner => BannerBlockView(block: banner),
      CarouselBlock carousel => CarouselBlockView(block: carousel),
      ProductGridBlock grid => ProductGridBlockView(block: grid),
      UnknownBlock() => const SizedBox.shrink(),
    };

class NoticeBlockView extends StatelessWidget {
  const NoticeBlockView({super.key, required this.block});
  final NoticeBlock block;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, color: AppColors.leaf, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              block.text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF1B1F1A)),
            ),
          ),
        ],
      ),
    );
  }
}

class BannerBlockView extends StatelessWidget {
  const BannerBlockView({super.key, required this.block});
  final BannerBlock block;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => openDeeplink(context, block.deeplink),
        child: AspectRatio(
          aspectRatio: 12 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(block.imageUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xCC12301F), Color(0x0012301F)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      block.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                    if (block.subtitle.isNotEmpty)
                      Text(
                        block.subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CarouselBlockView extends StatelessWidget {
  const CarouselBlockView({super.key, required this.block});
  final CarouselBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(block.title),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: block.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = block.items[i];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openDeeplink(context, item.deeplink),
                child: SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.square(
                          dimension: 80,
                          child: AppImage(item.imageUrl),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ProductGridBlockView extends StatelessWidget {
  const ProductGridBlockView({super.key, required this.block});
  final ProductGridBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(block.title),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: block.products.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 360,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, i) {
            final product = block.products[i];
            return ProductCard(
              product: product,
              onTap: () => openDeeplink(context, 'product/${product.id}'),
            );
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
