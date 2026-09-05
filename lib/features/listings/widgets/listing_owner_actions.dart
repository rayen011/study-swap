import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/listing_options.dart';
import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../logic/listing_cubit.dart';

/// What a seller can do with their own listing, in one place.
///
/// One sheet rather than a menu per screen: the actions were previously
/// scattered — a delete button on the Collection tab, nothing on the item
/// page, nothing on the profile grid, and no way to edit anywhere. A seller
/// who cannot correct a price they typed wrong has to delete the listing and
/// re-upload the photos.
Future<void> showListingOwnerActions({
  required BuildContext context,
  required Listing listing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _OwnerActions(
      listing: listing,
      // The cubit lives above the sheet's own context, which is mounted on the
      // root navigator.
      cubit: context.read<ListingCubit>(),
    ),
  );
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({required this.listing, required this.cubit});

  final Listing listing;
  final ListingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final isSold = listing.status == ListingStatus.sold;
    final isReserved = listing.status == ListingStatus.reserved;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Text(
              listing.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),
          ),

          if (listing.isAuction)
            const _Locked(
              icon: Icons.gavel_rounded,
              message:
                  'This is up for bids. Nothing about it can change while '
                  'people have credits staked on it.',
            )
          else if (isSold)
            const _Locked(
              icon: Icons.check_circle_outline,
              message:
                  'This one sold. It stays on your profile as part of your '
                  'record.',
            )
          else ...[
            _Action(
              icon: Icons.edit_outlined,
              label: 'Edit listing',
              detail: 'Title, price, photos, category, condition',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/edit-listing', extra: listing);
              },
            ),
            _Action(
              icon: isReserved
                  ? Icons.play_circle_outline
                  : Icons.pause_circle_outline,
              label: isReserved ? 'Put it back on sale' : 'Mark as reserved',
              detail: isReserved
                  ? 'It shows in the feed again and accepts deals'
                  : 'It stays visible but stops taking deal requests',
              onTap: () {
                Navigator.of(context).pop();
                cubit.setStatus(
                  listing.id,
                  isReserved ? ListingStatus.active : ListingStatus.reserved,
                );
              },
            ),
          ],

          if (!listing.isAuction)
            _Action(
              icon: Icons.delete_outline,
              label: 'Delete listing',
              detail: listing.hasImages
                  ? 'Removes it and its ${listing.imageUrls.length} '
                        'photo${listing.imageUrls.length == 1 ? '' : 's'}'
                  : 'This cannot be undone',
              danger: true,
              onTap: () async {
                Navigator.of(context).pop();
                final confirmed = await _confirmDelete(context, listing);
                if (confirmed) cubit.deleteListing(listing.id);
              },
            ),

          const SizedBox(height: AppSizes.sm),
        ],
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, Listing listing) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this listing?'),
      content: Text(
        listing.hasImages
            ? 'The listing and its ${listing.imageUrls.length} '
                  'photo${listing.imageUrls.length == 1 ? '' : 's'} go for good.'
            : 'It goes for good. There is no undo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'DELETE',
            style: TextStyle(color: AppColors.errorRed),
          ),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colour = danger ? AppColors.errorRed : AppColors.textDark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colour),
            AppSizes.gapWMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMediumDark.copyWith(color: colour),
                  ),
                  Text(
                    detail,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says why an action isn't on offer, rather than leaving a blank sheet.
class _Locked extends StatelessWidget {
  const _Locked({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textGrey),
          AppSizes.gapWSm,
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
