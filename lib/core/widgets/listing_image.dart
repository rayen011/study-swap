import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One listing photo, cached, with a consistent placeholder.
///
/// Every surface that shows a listing goes through this so a photoless listing,
/// a slow network and a dead URL all look the same wherever they appear.
class ListingImage extends StatelessWidget {
  const ListingImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
    this.placeholderIconSize = 40,
    this.placeholderColor = const Color(0xFFE5E7EB),
  });

  /// Null or empty renders the placeholder.
  final String? url;

  final BoxFit fit;
  final IconData placeholderIcon;
  final double placeholderIconSize;
  final Color placeholderColor;

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) return _placeholder();

    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => _placeholder(showSpinner: true),
      errorWidget: (_, _, _) => _placeholder(icon: Icons.broken_image_outlined),
    );
  }

  Widget _placeholder({IconData? icon, bool showSpinner = false}) {
    return Container(
      color: placeholderColor,
      alignment: Alignment.center,
      child: showSpinner
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textGrey,
              ),
            )
          : Icon(
              icon ?? placeholderIcon,
              size: placeholderIconSize,
              color: AppColors.textGrey,
            ),
    );
  }
}
