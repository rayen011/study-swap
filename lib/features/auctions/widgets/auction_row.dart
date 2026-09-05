import 'package:flutter/material.dart';

import '../../../core/models/auction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/room_colors.dart';
import '../../../core/widgets/listing_image.dart';
import 'countdown.dart';

/// Where the viewer stands in one auction.
///
/// Kept out of [Auction] because it depends on who is looking, and the auction
/// document does not know that.
enum AuctionStanding {
  /// Not involved.
  none,

  /// Yours to lose.
  leading,

  /// You bid, somebody went higher.
  outbid,

  /// You are selling it.
  selling,
}

AuctionStanding standingFor(Auction auction, String uid, List<Bid> yourBids) {
  if (auction.isSeller(uid)) return AuctionStanding.selling;
  if (auction.isLeading(uid)) return AuctionStanding.leading;
  return yourBids.any((bid) => bid.bidderId == uid)
      ? AuctionStanding.outbid
      : AuctionStanding.none;
}

/// One auction in the room's list.
class AuctionRow extends StatelessWidget {
  const AuctionRow({
    super.key,
    required this.auction,
    required this.onTap,
    this.standing = AuctionStanding.none,
    this.now,
  });

  final Auction auction;
  final AuctionStanding standing;
  final VoidCallback onTap;

  /// Fixes "now" for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final at = now ?? DateTime.now();
    final closing = auction.isInSnipeWindow(at);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          // The closing auction is the loudest thing in the list, because it
          // is the only one where looking now instead of later matters.
          border: Border.all(
            color: closing ? RoomColors.accent : RoomColors.line,
            width: closing ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 62,
                height: 62,
                child: ListingImage(
                  url: auction.listingImage.isEmpty
                      ? null
                      : auction.listingImage,
                  placeholderColor: RoomColors.raised,
                  placeholderIconSize: 22,
                ),
              ),
            ),
            AppSizes.gapWMD,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    auction.listingTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.buttonText.copyWith(
                      fontSize: 14,
                      color: RoomColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auction.hasBids
                        ? '${auction.bidCount} ${auction.bidCount == 1 ? 'bid' : 'bids'} · ${auction.sellerName}'
                        : 'No bids yet · ${auction.sellerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: RoomColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (closing)
                    _ClosingLine(auction: auction)
                  else if (standing != AuctionStanding.none)
                    _StandingTag(standing: standing)
                  else if (!auction.hasBids)
                    Text(
                      'Be the first — £${auction.startPrice.toStringAsFixed(0)} takes it',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: RoomColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            AppSizes.gapWSm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  auction.hasBids ? 'NOW AT' : 'OPENING AT',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: RoomColors.textTertiary,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '£${auction.displayPrice.toStringAsFixed(0)}',
                  style: AppTextStyles.heading2.copyWith(
                    fontSize: 22,
                    height: 1.1,
                    color: auction.hasBids
                        ? RoomColors.textPrimary
                        : RoomColors.textTertiary,
                  ),
                ),
                if (!closing)
                  Countdown(
                    endsAt: auction.endsAt,
                    builder: (context, left) => Text(
                      formatCountdown(left),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: RoomColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The last two minutes, spelled out — including why the clock may move.
class _ClosingLine extends StatelessWidget {
  const _ClosingLine({required this.auction});

  final Auction auction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 12, color: RoomColors.accent),
        const SizedBox(width: 5),
        Expanded(
          child: Countdown(
            endsAt: auction.endsAt,
            builder: (context, left) => Text(
              '${formatCountdown(left)} — a late bid adds two minutes',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: RoomColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StandingTag extends StatelessWidget {
  const _StandingTag({required this.standing});

  final AuctionStanding standing;

  @override
  Widget build(BuildContext context) {
    final (label, colour, filled) = switch (standing) {
      AuctionStanding.leading => ("YOU'RE LEADING", RoomColors.accent, true),
      AuctionStanding.outbid => ('OUTBID', RoomColors.warning, false),
      AuctionStanding.selling => ('YOURS', RoomColors.textSecondary, false),
      AuctionStanding.none => ('', RoomColors.line, false),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? colour : Colors.transparent,
        border: filled ? null : Border.all(color: colour),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: filled ? AppColors.solidBlack : colour,
        ),
      ),
    );
  }
}
