import 'dart:math' as math;

/// Credits: what a bid costs, and how you come to afford one.
///
/// Credits are earned by completing real trades. They are never bought and
/// never cashed out, which is the whole point — a currency with no purchase
/// path has no monetary value, so it stays a game mechanic rather than a
/// payments product.
///
/// **These numbers are a mirror, not the authority.** `functions/src/credits.ts`
/// owns them; every balance in Firestore is written by a Cloud Function and by
/// nothing else. What lives here is the app's ability to *explain* the rules
/// without a round trip. `test/credit_rules_test.dart` reads the TypeScript
/// file and fails if the two copies drift.
class CreditRules {
  const CreditRules._();

  /// What a new account opens with.
  static const int startingBalance = 50;

  /// Completing a deal as the seller.
  static const int sellerCompletion = 25;

  /// Completing a deal as the buyer.
  static const int buyerCompletion = 15;

  /// Receiving a five-star review.
  static const int fiveStarReview = 10;

  /// Receiving a four-star review.
  static const int fourStarReview = 5;

  /// Percent of a bid held as a stake while that bid stands.
  static const int stakePercent = 10;

  /// A bid may be up to this many times the available balance.
  static const int bidMultiplier = 10;

  /// Hard ceiling on any bid, whatever the reputation behind it.
  static const int maxBid = 2000;

  /// Credits awarded for a review of [rating] stars. Nothing below four.
  static int forReview(double rating) {
    final stars = rating.round();
    if (stars >= 5) return fiveStarReview;
    if (stars == 4) return fourStarReview;
    return 0;
  }

  /// The stake a bid of [amount] locks, rounded up to a whole credit.
  static int stakeFor(num amount) => (amount * stakePercent / 100).ceil();

  /// The largest bid an [available] balance permits.
  ///
  /// Available means unlocked: credits staked on a bid that is still standing
  /// don't count twice, which is what stops one member holding open bids on
  /// everything at once.
  static int maxBidFor(int available) =>
      math.min(math.max(0, available) * bidMultiplier, maxBid);

  /// How the balance grows, in the order it's worth reading on screen.
  static const List<CreditEarning> earnings = [
    CreditEarning('Joining StudySwap', startingBalance),
    CreditEarning('Completing a sale', sellerCompletion),
    CreditEarning('Completing a purchase', buyerCompletion),
    CreditEarning('A five-star review', fiveStarReview),
    CreditEarning('A four-star review', fourStarReview),
  ];
}

/// One row of the "how credits are earned" explanation.
class CreditEarning {
  const CreditEarning(this.label, this.amount);

  final String label;
  final int amount;
}
