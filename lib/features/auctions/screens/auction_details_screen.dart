import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/auction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/room_colors.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/listing_image.dart';
import '../../chat/screens/chat_details_screen.dart';
import '../../profile/data/user_repository.dart';
import '../data/auction_repository.dart';
import '../logic/auction_cubit.dart';
import '../logic/auction_state.dart';
import '../widgets/bid_sheet.dart';
import '../widgets/countdown.dart';

/// One auction: the clock, what it stands at, who bid what, and the button.
class AuctionDetailsScreen extends StatelessWidget {
  const AuctionDetailsScreen({super.key, required this.auctionId});

  final String auctionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AuctionDetailCubit(context.read<AuctionRepository>(), auctionId)
            ..watch(),
      child: const _AuctionDetailsView(),
    );
  }
}

class _AuctionDetailsView extends StatelessWidget {
  const _AuctionDetailsView();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RoomColors.ground,
        body: BlocConsumer<AuctionDetailCubit, AuctionDetailState>(
          listenWhen: (previous, current) =>
              current is AuctionDetailLoaded &&
              (current.refusal != null || current.lastBid != null),
          listener: (context, state) {
            if (state is! AuctionDetailLoaded) return;
            _announce(context, state);
            context.read<AuctionDetailCubit>().acknowledge();
          },
          builder: (context, state) => switch (state) {
            AuctionDetailError(:final message) => _Framed(
              child: ErrorStateView(
                error: message,
                onRetry: () => context.read<AuctionDetailCubit>().watch(),
                onDark: true,
              ),
            ),
            AuctionDetailMissing() => const _Framed(child: _Gone()),
            AuctionDetailLoaded(
              :final auction,
              :final bids,
              :final isBidding,
            ) =>
              _Loaded(auction: auction, bids: bids, isBidding: isBidding),
            _ => const Center(
              child: CircularProgressIndicator(color: RoomColors.accent),
            ),
          },
        ),
      ),
    );
  }

  /// The server's own words, either way.
  void _announce(BuildContext context, AuctionDetailLoaded state) {
    final messenger = ScaffoldMessenger.of(context);
    final refusal = state.refusal;
    final placed = state.lastBid;

    final (text, colour) = refusal != null
        ? (refusal, RoomColors.warning)
        : (
            placed!.extended
                // Worth saying out loud: a clock that jumps forward on its own
                // looks like a bug rather than the anti-snipe rule working.
                ? 'Bid placed at £${placed.amount}. A late bid — two minutes added.'
                : 'Bid placed at £${placed.amount}. ${placed.stakeLocked} credits held.',
            RoomColors.accent,
          );

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: refusal != null ? AppColors.white : AppColors.solidBlack,
          ),
        ),
        backgroundColor: refusal != null ? RoomColors.raised : colour,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: RoomColors.textPrimary,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gavel_rounded, size: 44, color: RoomColors.muted),
            AppSizes.gapHMD,
            Text(
              'This auction is gone',
              style: AppTextStyles.heading2.copyWith(
                fontSize: 20,
                color: RoomColors.textPrimary,
              ),
            ),
            AppSizes.gapHSm,
            Text(
              'The seller withdrew it. Any credits you had staked are back.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: RoomColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.auction,
    required this.bids,
    required this.isBidding,
  });

  final Auction auction;
  final List<Bid> bids;
  final bool isBidding;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Photo(auction: auction),
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auction.listingTitle,
                      style: AppTextStyles.heading2.copyWith(
                        fontSize: 20,
                        color: RoomColors.textPrimary,
                      ),
                    ),
                    AppSizes.gapHSm,
                    _Seller(auction: auction),
                    AppSizes.gapHMD,
                    _StandingAt(auction: auction),
                    AppSizes.gapHMD,
                    _History(bids: bids, uid: uid),
                  ],
                ),
              ),
            ],
          ),
        ),
        _BidBar(auction: auction, uid: uid, isBidding: isBidding),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.auction});

  final Auction auction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListingImage(
            url: auction.listingImage.isEmpty ? null : auction.listingImage,
            placeholderColor: RoomColors.raised,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.solidBlack.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: RoomColors.textPrimary,
                    iconSize: 20,
                  ),
                ),
              ),
            ),
          ),
          // The clock is the loudest thing on the screen — it is the one
          // element that makes this an auction rather than a listing.
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Countdown(
                endsAt: auction.endsAt,
                builder: (context, left) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: left > Duration.zero
                        ? RoomColors.accent
                        : RoomColors.raised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 15,
                        color: left > Duration.zero
                            ? AppColors.solidBlack
                            : RoomColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        left > Duration.zero
                            ? '${formatCountdown(left)} left'
                            : 'Bidding closed',
                        style: AppTextStyles.buttonText.copyWith(
                          fontSize: 17,
                          color: left > Duration.zero
                              ? AppColors.solidBlack
                              : RoomColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seller extends StatelessWidget {
  const _Seller({required this.auction});

  final Auction auction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(radius: 10, backgroundColor: RoomColors.raised),
        AppSizes.gapWSm,
        Text(
          auction.sellerName,
          style: AppTextStyles.bodySmall.copyWith(
            color: RoomColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StandingAt extends StatelessWidget {
  const _StandingAt({required this.auction});

  final Auction auction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoomColors.raised)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                auction.hasBids ? 'STANDING AT' : 'OPENING AT',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: RoomColors.textTertiary,
                ),
              ),
              Text(
                '£${auction.displayPrice.toStringAsFixed(0)}',
                style: AppTextStyles.heading1.copyWith(
                  fontSize: 40,
                  height: 1,
                  color: RoomColors.textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                auction.bidCount == 1 ? '1 bid' : '${auction.bidCount} bids',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 12,
                  color: RoomColors.textSecondary,
                ),
              ),
              if (auction.hasReserve) ...[
                const SizedBox(height: 4),
                _ReserveTag(auction: auction),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Says a reserve exists, never what it is — the number lives in a
/// subcollection only the seller can read.
class _ReserveTag extends StatelessWidget {
  const _ReserveTag({required this.auction});

  final Auction auction;

  @override
  Widget build(BuildContext context) {
    final met = auction.status.hasEnded && auction.reserveMet;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: met ? RoomColors.accent : RoomColors.reserve,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        auction.status.hasEnded
            ? (met ? 'RESERVE MET' : 'RESERVE NOT MET')
            : 'HAS A RESERVE',
        style: AppTextStyles.bodySmall.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: met ? RoomColors.accent : RoomColors.reserve,
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.bids, required this.uid});

  final List<Bid> bids;
  final String uid;

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Text(
          'No bids yet. The opening price takes it.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: RoomColors.textTertiary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BID HISTORY',
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 10,
            letterSpacing: 1,
            color: RoomColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < bids.length; i++)
          _HistoryRow(
            bid: bids[i],
            uid: uid,
            isLeading: i == 0,
            showDivider: i > 0,
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.bid,
    required this.uid,
    required this.isLeading,
    required this.showDivider,
  });

  final Bid bid;
  final String uid;
  final bool isLeading;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isYours = bid.bidderId == uid;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: RoomColors.raised)),
            )
          : null,
      child: Row(
        children: [
          const CircleAvatar(radius: 13, backgroundColor: RoomColors.raised),
          AppSizes.gapWSm,
          Expanded(
            child: Text(
              isYours ? 'You' : bid.bidderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: isLeading ? FontWeight.w600 : FontWeight.w400,
                color: isLeading
                    ? RoomColors.textPrimary
                    : RoomColors.textSecondary,
              ),
            ),
          ),
          Text(
            '£${bid.amount.toStringAsFixed(0)}',
            style: AppTextStyles.buttonText.copyWith(
              fontSize: 15,
              color: isLeading ? RoomColors.accent : RoomColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The minimum, then the button. Stated before, never discovered by refusal.
class _BidBar extends StatelessWidget {
  const _BidBar({
    required this.auction,
    required this.uid,
    required this.isBidding,
  });

  final Auction auction;
  final String uid;
  final bool isBidding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoomColors.line, width: 1.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.md, 14, AppSizes.md, 14),
          child: StreamBuilder<AppUser?>(
            stream: context.read<UserRepository>().watchUser(uid),
            builder: (context, snapshot) =>
                _bar(context, snapshot.data, DateTime.now()),
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context, AppUser? bidder, DateTime now) {
    // A closed auction you were part of is not a dead end: the deal is
    // waiting in a chat, and this is where somebody would look for it.
    final chatId = auction.chatId;
    final isWinner = auction.winnerId != null && auction.winnerId == uid;
    if (chatId != null && (isWinner || auction.isSeller(uid))) {
      return _OpenChat(
        chatId: chatId,
        isWinner: isWinner,
        otherName: isWinner ? auction.sellerName : 'the winner',
        price: auction.winningBid ?? auction.displayPrice,
      );
    }

    if (auction.isSeller(uid)) {
      return _Note(
        icon: Icons.storefront_outlined,
        text: auction.status.isLive
            ? 'This is yours. You cannot bid on it.'
            : 'This is yours. ${auction.status.label}.',
      );
    }

    if (!auction.acceptsBids(now)) {
      return _Note(
        icon: Icons.lock_outline_rounded,
        text: switch (auction.status) {
          AuctionStatus.endedUnsold
              when auction.hasReserve && !auction.reserveMet =>
            'It closed under the reserve. Nothing sold and every stake is back.',
          AuctionStatus.endedUnsold => 'It closed with nobody bidding.',
          AuctionStatus.abandoned =>
            'The winner never turned up. Their stake went to the seller.',
          _ => 'Bidding closed. ${auction.status.label}.',
        },
      );
    }

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MINIMUM BID',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 10,
                letterSpacing: 0.8,
                color: RoomColors.textTertiary,
              ),
            ),
            Text(
              '£${auction.minimumBid}',
              style: AppTextStyles.buttonText.copyWith(
                fontSize: 20,
                color: RoomColors.textPrimary,
              ),
            ),
          ],
        ),
        AppSizes.gapWMD,
        Expanded(
          child: GestureDetector(
            onTap: bidder == null || isBidding
                ? null
                : () async {
                    final cubit = context.read<AuctionDetailCubit>();
                    final amount = await showBidSheet(
                      context: context,
                      auction: auction,
                      bidder: bidder,
                    );
                    if (amount != null) await cubit.placeBid(amount);
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: isBidding ? RoomColors.line : RoomColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isBidding
                  ? const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: RoomColors.accent,
                        ),
                      ),
                    )
                  : Text(
                      auction.isLeading(uid) ? "YOU'RE LEADING" : 'PLACE A BID',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.buttonText.copyWith(
                        fontSize: 15,
                        color: AppColors.solidBlack,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: RoomColors.textTertiary),
        AppSizes.gapWSm,
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 13,
              color: RoomColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The way from a finished auction into the deal it created.
class _OpenChat extends StatelessWidget {
  const _OpenChat({
    required this.chatId,
    required this.isWinner,
    required this.otherName,
    required this.price,
  });

  final String chatId;
  final bool isWinner;
  final String otherName;
  final double price;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            isWinner
                ? "It's yours at £${price.toStringAsFixed(0)}. The deal is "
                      'waiting in your chat with $otherName.'
                : 'Sold at £${price.toStringAsFixed(0)}. The deal is in your '
                      'chat with $otherName.',
            style: AppTextStyles.bodySmall.copyWith(
              color: RoomColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        AppSizes.gapWMD,
        GestureDetector(
          onTap: () => context.push(
            '/chat-details',
            extra: ChatDetailsArgs(
              chatId: chatId,
              receiverName: otherName,
              receiverId: chatId
                  .split('_')
                  .firstWhere(
                    (id) => id != FirebaseAuth.instance.currentUser?.uid,
                    orElse: () => '',
                  ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: RoomColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'OPEN CHAT',
              style: AppTextStyles.buttonText.copyWith(
                fontSize: 14,
                color: AppColors.solidBlack,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
