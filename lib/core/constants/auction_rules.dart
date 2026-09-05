import 'credit_rules.dart';

/// The rules of the auction floor, as the app needs to explain them.
///
/// **A mirror, not the authority.** `functions/src/auctions.ts` decides what a
/// bid is actually worth — every one of these checks is re-run on the server,
/// where the client cannot reach it. What lives here is the app's ability to
/// grey out a bid button and say why before a round trip.
/// `test/auction_rules_test.dart` parses the TypeScript and fails on drift.
class AuctionRules {
  const AuctionRules._();

  /// A bid must beat the current one by at least this many pounds...
  static const int minIncrement = 1;

  /// ...or by this percentage of it, whichever is more.
  static const int incrementPercent = 5;

  /// A bid this close to the end pushes the end out.
  static const int snipeWindowMs = 120000;

  /// Total extension one auction may accumulate.
  static const int maxExtensionMs = 1800000;

  /// The lowest a seller may open at.
  static const int minStartPrice = 1;

  /// How many overdue auctions one scheduled close pass handles.
  static const int closeBatchSize = 50;

  /// The highest a seller may open at.
  ///
  /// Derived, not chosen: a floor opened above the maximum possible bid is one
  /// nobody in the app can bid on.
  static int get maxStartPrice => CreditRules.maxBid;

  static const Duration snipeWindow = Duration(milliseconds: snipeWindowMs);
  static const Duration maxExtension = Duration(milliseconds: maxExtensionMs);

  /// The durations a seller may pick.
  static const List<AuctionDuration> durations = [
    AuctionDuration(24, '24 hours'),
    AuctionDuration(72, '3 days'),
    AuctionDuration(168, '7 days'),
  ];

  /// The smallest bid that would be accepted right now.
  ///
  /// With no bids yet the starting price itself is biddable — the seller named
  /// it, so meeting it is a real offer. After that every bid clears the
  /// increment, rounded up to whole pounds.
  static int minimumBid(num startPrice, [num? currentBid]) {
    if (currentBid == null) return startPrice.ceil();

    final percent = currentBid * incrementPercent / 100;
    final increment = percent > minIncrement ? percent : minIncrement;
    return (currentBid + increment).ceil();
  }
}

/// One selectable auction length.
class AuctionDuration {
  const AuctionDuration(this.hours, this.label);

  final int hours;
  final String label;

  Duration get duration => Duration(hours: hours);
}
