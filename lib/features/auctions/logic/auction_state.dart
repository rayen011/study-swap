import 'package:equatable/equatable.dart';

import '../../../core/models/auction.dart';

// ── the room's list ──────────────────────────────────────────────────────

abstract class AuctionListState extends Equatable {
  const AuctionListState();

  @override
  List<Object?> get props => [];
}

class AuctionListInitial extends AuctionListState {
  const AuctionListInitial();
}

class AuctionListLoading extends AuctionListState {
  const AuctionListLoading();
}

class AuctionListLoaded extends AuctionListState {
  const AuctionListLoaded(this.auctions);

  final List<Auction> auctions;

  bool get isEmpty => auctions.isEmpty;

  @override
  List<Object?> get props => [auctions];
}

class AuctionListError extends AuctionListState {
  const AuctionListError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

// ── one auction ──────────────────────────────────────────────────────────

abstract class AuctionDetailState extends Equatable {
  const AuctionDetailState();

  @override
  List<Object?> get props => [];
}

class AuctionDetailLoading extends AuctionDetailState {
  const AuctionDetailLoading();
}

class AuctionDetailLoaded extends AuctionDetailState {
  const AuctionDetailLoaded({
    required this.auction,
    required this.bids,
    this.isBidding = false,
    this.refusal,
    this.lastBid,
  });

  final Auction auction;
  final List<Bid> bids;

  /// True while the callable is in flight, so the button can't be pressed
  /// twice — two identical bids would refuse the second anyway, but only
  /// after locking the network for a round trip.
  final bool isBidding;

  /// The server's own words when it turned a bid down. Shown as-is.
  final String? refusal;

  /// Set once, right after a bid lands, so the screen can acknowledge it.
  final BidOutcome? lastBid;

  AuctionDetailLoaded copyWith({
    Auction? auction,
    List<Bid>? bids,
    bool? isBidding,
    String? refusal,
    BidOutcome? lastBid,
    bool clearRefusal = false,
    bool clearLastBid = false,
  }) {
    return AuctionDetailLoaded(
      auction: auction ?? this.auction,
      bids: bids ?? this.bids,
      isBidding: isBidding ?? this.isBidding,
      refusal: clearRefusal ? null : (refusal ?? this.refusal),
      lastBid: clearLastBid ? null : (lastBid ?? this.lastBid),
    );
  }

  @override
  List<Object?> get props => [auction, bids, isBidding, refusal, lastBid];
}

class AuctionDetailMissing extends AuctionDetailState {
  const AuctionDetailMissing();
}

class AuctionDetailError extends AuctionDetailState {
  const AuctionDetailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// What happened to a bid that was accepted.
class BidOutcome extends Equatable {
  const BidOutcome({
    required this.amount,
    required this.stakeLocked,
    required this.extended,
  });

  final int amount;
  final int stakeLocked;

  /// True when the bid pushed the closing time out — worth saying out loud,
  /// because otherwise a clock that jumps forward looks like a bug.
  final bool extended;

  @override
  List<Object?> get props => [amount, stakeLocked, extended];
}
