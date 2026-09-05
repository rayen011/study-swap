import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../constants/auction_rules.dart';
import 'firestore_parsing.dart';

/// Where an auction is in its life.
///
/// The wire values are written by Cloud Functions and by nothing else, so an
/// unrecognised one means a newer server than this build of the app — which is
/// why [tryParse] returns null rather than guessing.
enum AuctionStatus {
  /// Open for bids.
  live('live', 'Live'),

  /// Time is up and it met its price. Waiting for the handover.
  endedSold('ended_sold', 'Sold'),

  /// Time is up with no bids, or none that met the reserve.
  endedUnsold('ended_unsold', 'Unsold'),

  /// The handover happened and everything is squared up.
  settled('settled', 'Settled'),

  /// The winner never showed. Their stake went to the seller.
  abandoned('abandoned', 'Abandoned')
  ;

  const AuctionStatus(this.wire, this.label);

  final String wire;
  final String label;

  static AuctionStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }

  bool get isLive => this == AuctionStatus.live;

  /// Whether the floor is closed, however it closed.
  bool get hasEnded => !isLive;
}

/// A listing being sold by auction rather than at a fixed price.
///
/// Read-only from the app's point of view. Every field here is written by a
/// Cloud Function; `firestore.rules` denies the client every write on
/// `auctions`, so nothing in this class has a setter or a `toMap`.
///
/// Note what is missing: the reserve price. A rule can deny a document but
/// cannot hide a field, so a reserve stored here would be readable by anyone
/// who bothered to look, which is the same as not having one. It lives in a
/// subcollection only the seller can read. All a bidder gets is [hasReserve]
/// and, once closed, [reserveMet].
class Auction extends Equatable {
  const Auction({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingImage,
    required this.sellerId,
    required this.sellerName,
    required this.startPrice,
    required this.currentBid,
    required this.currentBidderId,
    required this.bidCount,
    required this.status,
    required this.endsAt,
    required this.extensionsMs,
    required this.hasReserve,
    required this.reserveMet,
    required this.winnerId,
    required this.winningBid,
    required this.chatId,
    required this.createdAt,
  });

  final String id;
  final String listingId;

  /// Denormalised from the listing so a room of twenty auctions is twenty
  /// documents rather than forty. The same trade `chats` already makes with
  /// participant names, and bids with the bidder's.
  final String listingTitle;

  /// The listing's first photo, or empty when it has none.
  final String listingImage;

  final String sellerId;
  final String sellerName;

  final double startPrice;

  /// The leading bid, or null if nobody has bid yet.
  final double? currentBid;
  final String? currentBidderId;
  final int bidCount;

  final AuctionStatus status;

  /// When the floor closes. Moves later when a bid arrives near the end.
  final DateTime? endsAt;

  /// How much [endsAt] has already been pushed out, against the cap.
  final int extensionsMs;

  /// Whether a minimum price exists. Never what it is.
  final bool hasReserve;

  /// Meaningful only once the auction has ended.
  final bool reserveMet;

  final String? winnerId;
  final double? winningBid;

  /// The chat the handoff created, once it has been created.
  final String? chatId;

  final DateTime? createdAt;

  factory Auction.fromMap(String id, Map<String, dynamic> data) {
    final bid = data['currentBid'];

    return Auction(
      id: id,
      listingId: asString(data['listingId']),
      listingTitle: asString(data['listingTitle'], fallback: 'Untitled'),
      listingImage: asString(data['listingImage']),
      sellerId: asString(data['sellerId']),
      sellerName: asString(data['sellerName'], fallback: 'Student'),
      startPrice: asDouble(data['startPrice']),
      currentBid: bid is num ? bid.toDouble() : null,
      currentBidderId: data['currentBidderId'] is String
          ? data['currentBidderId'] as String
          : null,
      bidCount: asInt(data['bidCount']),
      // An unknown status means a newer server than this build, and every
      // status a newer server could add comes *after* live in the lifecycle.
      // Defaulting to closed shows an auction that can't be bid on; defaulting
      // to live would offer a Bid button the server is going to refuse.
      status:
          AuctionStatus.tryParse(data['status']) ?? AuctionStatus.endedUnsold,
      endsAt: asDate(data['endsAt']),
      extensionsMs: asInt(data['extensionsMs']),
      hasReserve: asBool(data['hasReserve']),
      reserveMet: asBool(data['reserveMet']),
      winnerId: data['winnerId'] is String ? data['winnerId'] as String : null,
      winningBid: data['winningBid'] is num
          ? (data['winningBid'] as num).toDouble()
          : null,
      chatId: data['chatId'] is String ? data['chatId'] as String : null,
      createdAt: asDate(data['createdAt']),
    );
  }

  static Auction? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return data == null ? null : Auction.fromMap(doc.id, data);
  }

  /// The smallest bid that would be accepted.
  int get minimumBid => AuctionRules.minimumBid(startPrice, currentBid);

  /// What the auction is standing at — the leading bid, or the opening price.
  double get displayPrice => currentBid ?? startPrice;

  bool get hasBids => currentBid != null;

  /// How long is left, or [Duration.zero] once the time has passed.
  ///
  /// Takes [now] so a countdown can be driven from a ticker and tested without
  /// waiting for real time to pass.
  Duration timeLeft(DateTime now) {
    final end = endsAt;
    if (end == null) return Duration.zero;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether a bid now would push the closing time out.
  bool isInSnipeWindow(DateTime now) {
    if (!status.isLive) return false;
    final left = timeLeft(now);
    return left > Duration.zero && left <= AuctionRules.snipeWindow;
  }

  /// Live, and the clock hasn't run out yet.
  ///
  /// The status alone isn't enough: a scheduled function closes auctions once
  /// a minute, so there is always a window where the document still says live
  /// and the time has already gone.
  bool acceptsBids(DateTime now) =>
      status.isLive && timeLeft(now) > Duration.zero;

  bool isSeller(String uid) => uid == sellerId;

  bool isLeading(String uid) =>
      currentBidderId != null && uid == currentBidderId;

  @override
  List<Object?> get props => [
    id,
    listingId,
    listingTitle,
    listingImage,
    sellerId,
    sellerName,
    startPrice,
    currentBid,
    currentBidderId,
    bidCount,
    status,
    endsAt,
    extensionsMs,
    hasReserve,
    reserveMet,
    winnerId,
    winningBid,
    chatId,
    createdAt,
  ];
}

/// What became of one bid.
enum BidStatus {
  /// Standing. Its stake is locked.
  active('active'),

  /// Beaten, or the auction closed without it winning. Stake returned.
  outbid('outbid'),

  /// Took the auction. Stake stays locked until the handover.
  won('won'),

  /// Won and never completed. Stake went to the seller.
  forfeited('forfeited')
  ;

  const BidStatus(this.wire);

  final String wire;

  static BidStatus? tryParse(Object? value) {
    if (value is! String) return null;
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// One bid, kept so a bidder can see they were outbid and when.
class Bid extends Equatable {
  const Bid({
    required this.id,
    required this.bidderId,
    required this.bidderName,
    required this.amount,
    required this.stakeLocked,
    required this.status,
    required this.placedAt,
  });

  final String id;
  final String bidderId;

  /// Denormalised so bid history doesn't need a profile read per row.
  final String bidderName;

  final double amount;

  /// Credits held against this bid while it stands.
  final int stakeLocked;

  final BidStatus status;
  final DateTime? placedAt;

  factory Bid.fromMap(String id, Map<String, dynamic> data) {
    return Bid(
      id: id,
      bidderId: asString(data['bidderId']),
      bidderName: asString(data['bidderName'], fallback: 'Student'),
      amount: asDouble(data['amount']),
      stakeLocked: asInt(data['stakeLocked']),
      status: BidStatus.tryParse(data['status']) ?? BidStatus.outbid,
      placedAt: asDate(data['placedAt']),
    );
  }

  static Bid? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return data == null ? null : Bid.fromMap(doc.id, data);
  }

  @override
  List<Object?> get props => [
    id,
    bidderId,
    bidderName,
    amount,
    stakeLocked,
    status,
    placedAt,
  ];
}

/// What a seller chooses when opening a floor.
///
/// Everything else about an auction — its status, its bid count, when it
/// closes — belongs to the server, which is why this carries so little.
class AuctionSetup extends Equatable {
  const AuctionSetup({
    required this.startPrice,
    required this.durationHours,
    this.reservePrice,
  });

  final int startPrice;
  final int durationHours;

  /// Null for no reserve. Never reaches the auction document itself.
  final int? reservePrice;

  @override
  List<Object?> get props => [startPrice, durationHours, reservePrice];
}
