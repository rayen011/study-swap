import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/auction.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/room_colors.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../profile/data/user_repository.dart';
import '../data/auction_repository.dart';
import '../logic/auction_cubit.dart';
import '../logic/auction_state.dart';
import '../widgets/auction_row.dart';

/// The Bid Room.
///
/// A full-screen route on the root navigator, so the tab bar is gone while you
/// are in here. That is the whole trick behind making it feel like a separate
/// place: not a sixth tab, but somewhere you enter and leave.
class BidRoomScreen extends StatelessWidget {
  const BidRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AuctionListCubit(context.read<AuctionRepository>())..watch(),
      child: const _BidRoomView(),
    );
  }
}

class _BidRoomView extends StatelessWidget {
  const _BidRoomView();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The status bar is on a black ground in here; the app's dark icons
      // would disappear into it.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RoomColors.ground,
        body: SafeArea(
          child: Column(
            children: [
              _Header(uid: uid),
              Expanded(
                child: BlocBuilder<AuctionListCubit, AuctionListState>(
                  builder: (context, state) => switch (state) {
                    AuctionListError(:final message) => ErrorStateView(
                      error: message,
                      onRetry: () => context.read<AuctionListCubit>().watch(),
                      onDark: true,
                    ),
                    AuctionListLoaded(:final auctions) when auctions.isEmpty =>
                      const _EmptyRoom(),
                    AuctionListLoaded(:final auctions) => _AuctionList(
                      auctions: auctions,
                      uid: uid,
                    ),
                    _ => const Center(
                      child: CircularProgressIndicator(
                        color: RoomColors.accent,
                      ),
                    ),
                  },
                ),
              ),
              const _Disclaimer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.md, 8, AppSizes.md, 16),
      child: Row(
        children: [
          // A chevron down, not a back arrow: you close this, you don't
          // navigate out of it.
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: RoomColors.textPrimary,
            iconSize: 28,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Leave the room',
          ),
          Text(
            'THE BID ROOM',
            style: AppTextStyles.buttonText.copyWith(
              fontSize: 17,
              letterSpacing: 1.5,
              color: RoomColors.textPrimary,
            ),
          ),
          const Spacer(),
          _CreditsPill(uid: uid),
        ],
      ),
    );
  }
}

/// The balance, in the header, because it is what you are spending.
class _CreditsPill extends StatelessWidget {
  const _CreditsPill({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: context.read<UserRepository>().watchUser(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: RoomColors.line, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 14, color: RoomColors.accent),
              const SizedBox(width: 6),
              Text(
                user == null ? '—' : '${user.availableCredits}',
                style: AppTextStyles.buttonText.copyWith(
                  fontSize: 13,
                  color: RoomColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuctionList extends StatelessWidget {
  const _AuctionList({required this.auctions, required this.uid});

  final List<Auction> auctions;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        0,
        AppSizes.md,
        AppSizes.md,
      ),
      itemCount: auctions.length,
      itemBuilder: (context, index) {
        final auction = auctions[index];

        return AuctionRow(
          auction: auction,
          // The list has no bid history, so "outbid" can't be told from "not
          // involved" here — the detail screen knows and says so.
          standing: auction.isSeller(uid)
              ? AuctionStanding.selling
              : auction.isLeading(uid)
              ? AuctionStanding.leading
              : AuctionStanding.none,
          onTap: () => context.push('/bid-room/${auction.id}'),
        );
      },
    );
  }
}

class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.gavel_rounded,
              size: 48,
              color: RoomColors.muted,
            ),
            AppSizes.gapHMD,
            Text(
              'The floor is empty',
              style: AppTextStyles.heading2.copyWith(
                fontSize: 20,
                color: RoomColors.textPrimary,
              ),
            ),
            AppSizes.gapHSm,
            Text(
              'Nothing is up for bids right now. If you have something whose '
              'worth you genuinely cannot guess, this is the place for it.',
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

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSizes.md, 14, AppSizes.md, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: RoomColors.raised)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 14,
            color: RoomColors.textTertiary,
          ),
          AppSizes.gapWSm,
          Expanded(
            child: Text(
              'Credits have no monetary value and cannot be bought.',
              style: AppTextStyles.bodySmall.copyWith(
                color: RoomColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
