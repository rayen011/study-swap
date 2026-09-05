/**
 * Credits: the bidding economy's numbers, in one place.
 *
 * Credits are earned by completing real trades, never bought and never cashed
 * out. They exist to make a bid cost something, so that an unbacked £90,000
 * bid on a signed football is arithmetically impossible rather than merely
 * discouraged. A member's ceiling is a function of the deals they have
 * actually completed.
 *
 * This file is the authority. `lib/core/constants/credit_rules.dart` mirrors
 * these numbers so the app can explain them without a round trip, and
 * `test/credit_rules_test.dart` parses this file and fails if the two ever
 * drift apart.
 *
 * Nothing here is client-writable: `credits` and `creditsLocked` are absent
 * from every update shape in `firestore.rules`, exactly like `rating` and
 * `dealCount`. The one exception is account creation, where the rules pin the
 * opening balance to `startingBalance` — a value a new account can only write
 * if it writes precisely that.
 */

export const CREDITS = {
  /** What a new account opens with: enough to take part, not enough to distort. */
  startingBalance: 50,

  /** Completing a deal as the seller. Sellers carry more of a handover's risk. */
  sellerCompletion: 25,

  /** Completing a deal as the buyer. Showing up and paying is the behaviour bought. */
  buyerCompletion: 15,

  /** Receiving a five-star review. Ties bidding power to how you're actually rated. */
  fiveStarReview: 10,

  /** Receiving a four-star review. */
  fourStarReview: 5,

  /** Percent of a bid locked as a stake while the bid stands. */
  stakePercent: 10,

  /** A bid may be up to this many times the available balance. */
  bidMultiplier: 10,

  /** Hard ceiling on any bid, no matter how good the reputation. */
  maxBid: 2000,
} as const;

/** Credits awarded for a review of [rating] stars. Zero for three or fewer. */
export function creditsForReview(rating: number): number {
  const stars = Math.round(rating);
  if (stars >= 5) return CREDITS.fiveStarReview;
  if (stars === 4) return CREDITS.fourStarReview;
  return 0;
}

/** The stake locked by a bid of [amount], rounded up to a whole credit. */
export function stakeFor(amount: number): number {
  return Math.ceil((amount * CREDITS.stakePercent) / 100);
}

/**
 * The largest bid an [available] balance permits.
 *
 * Available means unlocked: credits already staked on a live bid don't count
 * twice, which is what stops one member holding open bids on everything.
 */
export function maxBidFor(available: number): number {
  const uncapped = Math.max(0, available) * CREDITS.bidMultiplier;
  return Math.min(uncapped, CREDITS.maxBid);
}
