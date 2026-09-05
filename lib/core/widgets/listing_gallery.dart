import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'listing_image.dart';

/// How a multi-image gallery signals there is more than one photo.
enum GalleryIndicator {
  /// A row of dots. Reads at a glance on a small card.
  dots,

  /// A "2 / 5" pill. Clearer when the exact count matters.
  counter,

  /// Nothing — for when the caller draws its own, like a thumbnail strip.
  none,
}

/// A swipeable set of listing photos.
///
/// Used on the feed and Collection cards so photos can be browsed without
/// opening the listing, and on the details screen where a thumbnail strip
/// drives the same [PageController].
///
/// A listing with one photo renders a plain image rather than a `PageView`:
/// there is nothing to swipe to, and a card list holding twenty idle page
/// views for no reason is worth avoiding.
class ListingGallery extends StatefulWidget {
  const ListingGallery({
    super.key,
    required this.imageUrls,
    this.indicator = GalleryIndicator.dots,
    this.controller,
    this.onPageChanged,
    this.placeholderIconSize = 50,
    this.placeholderColor = const Color(0xFFE5E7EB),
  });

  final List<String> imageUrls;
  final GalleryIndicator indicator;

  /// Supply one to drive the gallery from outside, as the details screen's
  /// thumbnail strip does. Ownership stays with the caller.
  final PageController? controller;

  final ValueChanged<int>? onPageChanged;
  final double placeholderIconSize;
  final Color placeholderColor;

  @override
  State<ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends State<ListingGallery> {
  PageController? _ownedController;
  int _index = 0;

  PageController get _controller =>
      widget.controller ?? (_ownedController ??= PageController());

  @override
  void dispose() {
    // Only dispose the one we made; an injected controller belongs to its owner.
    _ownedController?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (mounted) setState(() => _index = index);
    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;

    if (urls.length < 2) {
      return ListingImage(
        url: urls.isEmpty ? null : urls.first,
        placeholderIconSize: widget.placeholderIconSize,
        placeholderColor: widget.placeholderColor,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // The horizontal drag is claimed here; the vertical list scroll and
        // the card's own tap both still get through.
        PageView.builder(
          controller: _controller,
          itemCount: urls.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) => Semantics(
            label: 'Photo ${index + 1} of ${urls.length}',
            child: ListingImage(
              url: urls[index],
              placeholderIconSize: widget.placeholderIconSize,
              placeholderColor: widget.placeholderColor,
            ),
          ),
        ),
        if (widget.indicator == GalleryIndicator.dots)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: _Dots(count: urls.length, active: _index),
          ),
        if (widget.indicator == GalleryIndicator.counter)
          Positioned(
            right: 16,
            bottom: 16,
            child: _Counter(current: _index + 1, total: urls.length),
          ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: isActive ? 16 : 6,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.white
                : AppColors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: AppColors.solidBlack.withValues(alpha: 0.25),
            ),
          ),
        );
      }),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.solidBlack.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$current / $total',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
