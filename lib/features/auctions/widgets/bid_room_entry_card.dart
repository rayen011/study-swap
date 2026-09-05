import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/auction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/room_colors.dart';
import '../data/auction_repository.dart';
import 'countdown.dart';

/// The door into the Bid Room, sitting in the marketplace feed.
///
/// Deliberately the same anatomy as the credits card on the profile — black
/// ground, lime offset shadow — because they are two halves of one idea: that
/// card is what you earn, this is where you spend it. Everything else in the
/// feed is a white card with a black shadow, so a black card with a lime one
/// reads as a piece of somewhere else.
///
/// There is no sixth navigation tab, and there shouldn't be. A tab makes the
/// room a permanent fifth of the app; a card in the feed makes it a place you
/// choose to go.
class BidRoomEntryCard extends StatelessWidget {
  const BidRoomEntryCard({
    super.key,
    required this.liveCount,
    required this.onTap,
    this.closingSoonest,
  });

  /// How many auctions are open. Zero still shows the card — an empty room
  /// that says so is better than a door that vanishes.
  final int liveCount;

  /// The auction closing next, shown as a ticker so the card has a pulse.
  final Auction? closingSoonest;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soonest = closingSoonest;

    return Semantics(
      button: true,
      label: 'The Bid Room. $liveCount auctions live.',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: RoomColors.ground,
            border: Border.all(color: RoomColors.ground, width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: RoomColors.accent, offset: Offset(3, 3)),
            ],
          ),
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.gavel_rounded,
                    size: 16,
                    color: RoomColors.accent,
                  ),
                  AppSizes.gapWSm,
                  // Flexible, not fixed: the title plus a three-digit count
                  // has under a pixel of slack on a 320px phone, so the
                  // label has to be the thing that gives.
                  Flexible(
                    child: Text(
                      'THE BID ROOM',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: RoomColors.accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (liveCount > 0) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: RoomColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$liveCount live',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: RoomColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Don't know what it's worth?\nLet the room decide.",
                style: AppTextStyles.heading2.copyWith(
                  color: RoomColors.textPrimary,
                  fontSize: 22,
                  height: 1.15,
                ),
              ),
              if (soonest != null) ...[
                const SizedBox(height: 12),
                _Ticker(auction: soonest),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      liveCount > 0
                          ? 'Bids cost credits, not money.'
                          : 'Nothing open yet. Be the first to open a floor.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: RoomColors.textTertiary,
                      ),
                    ),
                  ),
                  AppSizes.gapWSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: RoomColors.accent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ENTER',
                          style: AppTextStyles.buttonText.copyWith(
                            fontSize: 13,
                            color: AppColors.solidBlack,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.solidBlack,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The next auction to close, so the card has a pulse rather than a slogan.
class _Ticker extends StatelessWidget {
  const _Ticker({required this.auction});

  final Auction auction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RoomColors.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  auction.listingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: RoomColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  auction.bidCount == 1 ? '1 bid' : '${auction.bidCount} bids',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: RoomColors.textTertiary,
                    fontSize: 11,
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
                '£${auction.displayPrice.toStringAsFixed(0)}',
                style: AppTextStyles.buttonText.copyWith(
                  fontSize: 15,
                  color: RoomColors.accent,
                ),
              ),
              Countdown(
                endsAt: auction.endsAt,
                builder: (context, left) => Text(
                  formatCountdown(left),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: RoomColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The entry card wired to the live floor.
///
/// Hidden only while the first snapshot is still in flight, so the feed
/// doesn't flash a card that then changes shape.
///
/// If the query *fails*, the door still opens. That distinction was worth
/// making the hard way: with the read denied, an entry that hid on error made
/// the whole feature silently cease to exist — no card, no message, nothing to
/// debug from the outside. The room itself has an [ErrorStateView] and can say
/// what went wrong; the feed's job is only to keep the way in.
class BidRoomEntry extends StatelessWidget {
  const BidRoomEntry({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Auction>>(
      stream: context.read<AuctionRepository>().watchLive(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final auctions = snapshot.data ?? const <Auction>[];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.md),
          child: BidRoomEntryCard(
            liveCount: auctions.length,
            closingSoonest: auctions.isEmpty ? null : auctions.first,
            onTap: onTap,
          ),
        );
      },
    );
  }
}
