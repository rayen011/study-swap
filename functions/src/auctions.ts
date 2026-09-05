/**
 * Auctions: the rules of the floor, and the function that closes it.
 *
 * An auction is adversarial in a way nothing else in StudySwap is — everybody
 * in it wants to win — so the client is allowed to write exactly one thing: a
 * request to bid, and even that goes through a callable. `firestore.rules`
 * denies every client write to `auctions` and `auctions/{id}/bids`. What the
 * app does here is read.
 *
 * The reserve price is the exception worth explaining. Rules can deny a
 * document but cannot hide a field, so a reserve stored on the auction itself
 * would be readable by every bidder who opened a network inspector — which is
 * the same as not having one. It lives in `auctions/{id}/private/config`,
 * readable only by the seller. The public document carries `hasReserve` and,
 * after closing, `reserveMet`, which is all a bidder is entitled to know.
 *
 * This file is the authority for the numbers below;
 * `lib/core/constants/auction_rules.dart` mirrors them and
 * `test/auction_rules_test.dart` fails if the two drift.
 */

import { getFirestore, FieldValue, Timestamp, Transaction } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

import { CREDITS } from "./credits";

/** Same region as everything else, so they share a cold-start pool. */
const region = "europe-west2";

/**
 * Firestore is fetched per call rather than at module load, so this file can
 * be imported by a test that initialises the Admin SDK itself.
 */
const db = () => getFirestore();

export const AUCTION = {
  /** A bid must beat the current one by at least this many pounds... */
  minIncrement: 1,

  /** ...or by this percentage of it, whichever is more. */
  incrementPercent: 5,

  /**
   * A bid landing within this long of the end pushes the end out.
   *
   * Without it the winner is whoever has the best reflexes at closing time,
   * and everybody else learns not to bother bidding early.
   */
  snipeWindowMs: 120_000,

  /** Total extension one auction may accumulate, so it can't run forever. */
  maxExtensionMs: 1_800_000,

  /** Nothing is worth bidding on at 50p, and rounding gets silly below it. */
  minStartPrice: 1,

  /** How many overdue auctions one scheduled run will close. */
  closeBatchSize: 50,
} as const;

/**
 * The highest a starting price may be.
 *
 * Derived rather than chosen: a floor opened above the maximum possible bid is
 * one nobody in the app is able to bid on.
 */
export const maxStartPrice = CREDITS.maxBid;

/** The durations a seller may pick, in hours. */
export const AUCTION_DURATIONS_HOURS = [24, 72, 168] as const;

/**
 * The smallest bid that would be accepted right now.
 *
 * With no bids yet the starting price itself is biddable — the seller named
 * it, so meeting it is a real offer. After that, every bid must clear the
 * increment.
 */
export function minimumBidFor(startPrice: number, currentBid?: number | null): number {
  if (typeof currentBid !== "number") return startPrice;

  const percent = (currentBid * AUCTION.incrementPercent) / 100;
  const increment = Math.max(AUCTION.minIncrement, percent);

  // Whole pounds: a £52.55 minimum invites a £52.56 bid and reads as noise.
  return Math.ceil(currentBid + increment);
}

/**
 * Where the end moves to when a bid lands, and whether it moved at all.
 *
 * Extensions accumulate against a cap, so an auction being sniped repeatedly
 * settles instead of running all night.
 */
export function extendedEnd(
  endsAtMs: number,
  extensionsMs: number,
  nowMs: number,
): { endsAtMs: number; extensionsMs: number } {
  const remaining = endsAtMs - nowMs;
  if (remaining > AUCTION.snipeWindowMs) return { endsAtMs, extensionsMs };

  const wanted = nowMs + AUCTION.snipeWindowMs;
  const budget = AUCTION.maxExtensionMs - extensionsMs;
  if (budget <= 0) return { endsAtMs, extensionsMs };

  const granted = Math.min(wanted - endsAtMs, budget);
  if (granted <= 0) return { endsAtMs, extensionsMs };

  return { endsAtMs: endsAtMs + granted, extensionsMs: extensionsMs + granted };
}

// ─────────────────────────────────────────────────────────── closing

export type SettleOutcome =
  | "missing"
  | "not_live"
  | "not_due"
  | "ended_sold"
  | "ended_unsold";

export interface SettleResult {
  outcome: SettleOutcome;
  winnerId?: string;
  winningBid?: number;
  stakesReleased?: number;
}

/**
 * Closes one auction whose time is up.
 *
 * Runs as a single transaction because everything it touches has to move
 * together: the auction's status, the fate of every bid still standing, and
 * the credits those bids were holding. Half of this applied is worse than none
 * of it — a bidder whose auction closed but whose stake stayed locked has lost
 * credits to a bug.
 *
 * Safe to call twice. The status check inside the transaction means a second
 * run finds the auction already closed and does nothing, which matters because
 * a scheduled function is retried on failure and may overlap with itself.
 *
 * What it deliberately does *not* do: create the chat and the deal card for
 * the winner. That is the handoff, and it belongs with settlement.
 */
export async function settleAuction(
  auctionId: string,
  now = new Date(),
): Promise<SettleResult> {
  const auctionRef = db().collection("auctions").doc(auctionId);
  const configRef = auctionRef.collection("private").doc("config");
  const activeBids = auctionRef.collection("bids").where("status", "==", "active");

  return db().runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(auctionRef);
    if (!snap.exists) return { outcome: "missing" as const };

    const auction = snap.data() ?? {};
    if (auction.status !== "live") return { outcome: "not_live" as const };

    const endsAt = auction.endsAt as Timestamp | undefined;
    if (endsAt && endsAt.toMillis() > now.getTime()) {
      return { outcome: "not_due" as const };
    }

    // All reads before any write — Firestore transactions require it.
    const [configSnap, bidsSnap] = await Promise.all([
      tx.get(configRef),
      tx.get(activeBids),
    ]);

    const reserve = configSnap.data()?.reservePrice;
    const hasReserve = typeof reserve === "number";

    const highBid = typeof auction.currentBid === "number" ? auction.currentBid : null;
    const highBidderId =
      typeof auction.currentBidderId === "string" ? auction.currentBidderId : null;

    const reserveMet = !hasReserve || (highBid !== null && highBid >= reserve);
    const sold = highBid !== null && highBidderId !== null && reserveMet;

    // The stake on a losing bid goes back. The winner's stays locked until the
    // handover either happens or doesn't — that is what makes winning mean
    // something, and releasing it here would give a winner nothing to lose.
    const releasing = bidsSnap.docs.filter(
      (doc) => !(sold && doc.data().bidderId === highBidderId),
    );

    const bidderRefs = [
      ...new Set(
        releasing
          .map((doc) => doc.data().bidderId)
          .filter((id): id is string => typeof id === "string"),
      ),
    ].map((id) => db().collection("users").doc(id));

    const bidderSnaps = bidderRefs.length
      ? await tx.getAll(...bidderRefs)
      : [];

    // ── writes ──

    const released = new Map<string, number>();
    for (const doc of releasing) {
      const bid = doc.data();
      const bidderId = bid.bidderId;
      const stake = typeof bid.stakeLocked === "number" ? bid.stakeLocked : 0;

      tx.update(doc.ref, { status: "outbid", releasedAt: FieldValue.serverTimestamp() });

      if (typeof bidderId === "string" && stake > 0) {
        released.set(bidderId, (released.get(bidderId) ?? 0) + stake);
      }
    }

    for (const userSnap of bidderSnaps) {
      if (!userSnap.exists) continue;

      const stake = released.get(userSnap.id) ?? 0;
      if (stake === 0) continue;

      const locked = userSnap.get("creditsLocked");
      const current = typeof locked === "number" ? locked : 0;

      // Clamped rather than decremented blindly: if the locked total is ever
      // behind the stakes it represents, the member should end at zero, not
      // owing credits they can never work off.
      tx.update(userSnap.ref, { creditsLocked: Math.max(0, current - stake) });
    }

    if (sold) {
      const winningBid = bidsSnap.docs.find(
        (doc) => doc.data().bidderId === highBidderId,
      );
      if (winningBid) tx.update(winningBid.ref, { status: "won" });
    }

    tx.update(auctionRef, {
      status: sold ? "ended_sold" : "ended_unsold",
      reserveMet,
      winnerId: sold ? highBidderId : null,
      winningBid: sold ? highBid : null,
      endedAt: FieldValue.serverTimestamp(),
    });

    return {
      outcome: sold ? ("ended_sold" as const) : ("ended_unsold" as const),
      ...(sold ? { winnerId: highBidderId, winningBid: highBid } : {}),
      stakesReleased: releasing.length,
    };
  });
}

/**
 * Closes every auction whose time has passed.
 *
 * This cannot be the client's job. Nobody's phone is guaranteed to be open at
 * the moment an auction ends, and the one device that is guaranteed to care —
 * the leading bidder's — is the last one that should be deciding it won.
 *
 * Auctions are settled one at a time and one failure does not stop the batch:
 * a single malformed auction shouldn't hold up everybody else's closing time.
 * Anything missed is picked up by the next run a minute later, which is also
 * what makes [settleAuction]'s repeat-safety load-bearing.
 */
export const closeExpiredAuctions = onSchedule(
  { schedule: "every 1 minutes", region },
  async () => {
    const due = await db()
      .collection("auctions")
      .where("status", "==", "live")
      .where("endsAt", "<=", Timestamp.now())
      .orderBy("endsAt")
      .limit(AUCTION.closeBatchSize)
      .get();

    if (due.empty) return;

    let sold = 0;
    let unsold = 0;
    let failed = 0;

    for (const doc of due.docs) {
      try {
        const result = await settleAuction(doc.id);
        if (result.outcome === "ended_sold") sold++;
        if (result.outcome === "ended_unsold") unsold++;
      } catch (error) {
        failed++;
        logger.error("Could not close auction", { auctionId: doc.id, error });
      }
    }

    logger.info("Auction close pass finished", {
      considered: due.size,
      sold,
      unsold,
      failed,
    });
  },
);

// ─────────────────────────────────────────────────────────── opening a floor

/**
 * Opens an auction on a listing the caller owns.
 *
 * A callable rather than a client write because half of what an auction
 * document holds is not the seller's to set: the status, the bid count, the
 * closing time. A seller who could write `endsAt` could end the auction the
 * moment the price suited them, and one who could write `status` could skip
 * the closer entirely.
 *
 * The reserve goes to `auctions/{id}/private/config`, which only the seller
 * can read. Rules can deny a document but cannot hide a field, so a reserve
 * stored on the auction itself would be visible to every bidder — which is
 * the same as not having a hidden reserve at all.
 */
export async function createAuction(
  sellerId: string,
  listingId: string,
  startPrice: number,
  durationHours: number,
  reservePrice?: number | null,
  now = new Date(),
): Promise<{ auctionId: string; endsAt: number }> {
  if (!Number.isInteger(startPrice)) {
    throw new HttpsError("invalid-argument", "Set an opening price in whole pounds.");
  }
  if (startPrice < AUCTION.minStartPrice || startPrice > maxStartPrice) {
    throw new HttpsError(
      "invalid-argument",
      `An opening price has to be between £${AUCTION.minStartPrice} and ` +
        `£${maxStartPrice} — above that, nobody in the app could bid on it.`,
    );
  }
  if (!AUCTION_DURATIONS_HOURS.includes(durationHours as never)) {
    throw new HttpsError("invalid-argument", "Pick one of the offered durations.");
  }

  const hasReserve = typeof reservePrice === "number";
  if (hasReserve) {
    if (!Number.isInteger(reservePrice)) {
      throw new HttpsError("invalid-argument", "Set a reserve in whole pounds.");
    }
    if (reservePrice < startPrice) {
      throw new HttpsError(
        "invalid-argument",
        "A reserve below the opening price would never stop anything.",
      );
    }
    if (reservePrice > maxStartPrice) {
      throw new HttpsError(
        "invalid-argument",
        `A reserve above £${maxStartPrice} could never be met.`,
      );
    }
  }

  const listingRef = db().collection("listings").doc(listingId);
  const auctionRef = db().collection("auctions").doc();

  const endsAtMs = now.getTime() + durationHours * 3_600_000;

  await db().runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(listingRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "That listing is no longer here.");
    }

    const listing = snap.data() ?? {};

    if (listing.userId !== sellerId) {
      throw new HttpsError(
        "permission-denied",
        "You can only auction your own listing.",
      );
    }
    // One floor per listing. Without this a seller could open a second
    // auction on an item already being bid on, and both sets of bidders
    // would have a claim on it.
    if (typeof listing.auctionId === "string") {
      throw new HttpsError(
        "failed-precondition",
        "This is already up for bids.",
      );
    }
    if (listing.status !== "active") {
      throw new HttpsError(
        "failed-precondition",
        "Only an active listing can go up for bids.",
      );
    }

    tx.set(auctionRef, {
      listingId,
      // Denormalised so the room reads one document per row rather than two.
      listingTitle: typeof listing.title === "string" ? listing.title : "Untitled",
      listingImage: Array.isArray(listing.imageUrls) && listing.imageUrls.length
        ? listing.imageUrls[0]
        : "",
      sellerId,
      sellerName:
        typeof listing.sellerName === "string" ? listing.sellerName : "Student",
      startPrice,
      currentBid: null,
      currentBidderId: null,
      bidCount: 0,
      status: "live",
      endsAt: Timestamp.fromMillis(endsAtMs),
      extensionsMs: 0,
      // The fact of a reserve is public; the number is not.
      hasReserve,
      reserveMet: false,
      winnerId: null,
      winningBid: null,
      chatId: null,
      createdAt: FieldValue.serverTimestamp(),
    });

    if (hasReserve) {
      tx.set(auctionRef.collection("private").doc("config"), { reservePrice });
    }

    tx.update(listingRef, {
      saleMode: "auction",
      auctionId: auctionRef.id,
      price: startPrice,
    });
  });

  logger.info("Auction opened", { auctionId: auctionRef.id, listingId, sellerId });

  return { auctionId: auctionRef.id, endsAt: endsAtMs };
}

export const createAuctionCallable = onCall({ region }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to open a floor.");
  }

  const { listingId, startPrice, durationHours, reservePrice } = request.data ?? {};

  if (typeof listingId !== "string" || listingId.length === 0) {
    throw new HttpsError("invalid-argument", "Which listing?");
  }
  if (typeof startPrice !== "number" || typeof durationHours !== "number") {
    throw new HttpsError("invalid-argument", "An opening price and a duration are required.");
  }

  return createAuction(
    request.auth.uid,
    listingId,
    startPrice,
    durationHours,
    typeof reservePrice === "number" ? reservePrice : null,
  );
});
