/**
 * The credit constants, read out of the file that owns them.
 *
 * `functions/src/credits.ts` is the authority — it is the code that actually
 * writes balances. These scripts need the same numbers, and a third hand-typed
 * copy would eventually disagree with the other two, so this parses the
 * TypeScript source rather than restating it. The Dart mirror is kept honest
 * the same way, by `test/credit_rules_test.dart`.
 */

import { readFileSync } from "node:fs";

const SOURCE = new URL("../functions/src/credits.ts", import.meta.url);

function parseCredits() {
  const source = readFileSync(SOURCE, "utf8");
  const block = /export const CREDITS = \{([\s\S]*?)\} as const;/.exec(source);

  if (!block) {
    throw new Error(
      "Could not find CREDITS in functions/src/credits.ts. If it was renamed " +
        "or restructured, update tools/credit-rules.mjs to match.",
    );
  }

  const values = {};
  for (const [, key, value] of block[1].matchAll(/(\w+):\s*(\d+),/g)) {
    values[key] = Number(value);
  }
  return values;
}

export const CREDITS = parseCredits();

/**
 * The balance a member with this history would have accumulated.
 *
 * Firestore records how many deals somebody has completed, but not which side
 * of each one they were on, so past deals are credited at the buyer rate — the
 * smaller of the two. Under-awarding is the safe direction: credits are a bid
 * ceiling, and one that is slightly low costs a member nothing they can't earn
 * back on their next trade.
 */
export function creditsFromHistory({ dealCount = 0, ratingCount = 0, rating = 0 }) {
  const fromDeals = dealCount * CREDITS.buyerCompletion;

  // Only the average is stored, not the individual stars, so the reviews are
  // valued at whatever that average rounds to.
  const perReview =
    Math.round(rating) >= 5
      ? CREDITS.fiveStarReview
      : Math.round(rating) === 4
        ? CREDITS.fourStarReview
        : 0;

  return CREDITS.startingBalance + fromDeals + ratingCount * perReview;
}
