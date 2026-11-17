import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../catalog/presentation/catalog_widgets.dart';
import '../../../catalog/presentation/search_screen.dart'
    show productGridDelegate;
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
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      decoration: BoxDecoration(
        color: context.palette.warnSoft,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.palette.warnBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.campaign_outlined,
              color: context.palette.warnIcon,
              size: 18,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              block.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.onWarnSoft,
                    fontWeight: FontWeight.w500,
                  ),
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
    final text = Theme.of(context).textTheme;
    final hasLink = block.deeplink != null && block.deeplink!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Material(
        color: AppColors.leafDark,
        child: InkWell(
          onTap: hasLink ? () => openDeeplink(context, block.deeplink) : null,
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
                      colors: [Color(0xE612301F), Color(0x0012301F)],
                      stops: [0.15, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.lg + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        block.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      if (block.subtitle.isNotEmpty) ...[
                        const SizedBox(height: Gap.xs),
                        Text(
                          block.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      if (hasLink) ...[
                        const SizedBox(height: Gap.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Shop now',
                            style: text.labelMedium?.copyWith(
                              color: AppColors.leaf,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
        SectionTitle(block.title),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: block.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: Gap.md),
            itemBuilder: (context, i) {
              final item = block.items[i];
              return InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () => openDeeplink(context, item.deeplink),
                child: SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: context.palette.accentSoft,
                          borderRadius: BorderRadius.circular(Radii.lg),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.lg - 3),
                          child: AppImage(item.imageUrl),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
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
        SectionTitle(block.title),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: block.products.length,
          gridDelegate: productGridDelegate,
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

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
