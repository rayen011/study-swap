/**
 * Placing a bid.
 *
 * The riskiest function in the app, and the reason `firestore.rules` denies
 * every client write on `auctions`. A bid is the one thing a client asks for
 * and the server decides: whether it beats the current one by enough, whether
 * the bidder can back it, what it costs to hold, who gets released, and
 * whether the clock moves.
 *
 * All of it happens in ONE Firestore transaction. Two people bidding £51 in
 * the same millisecond must not both become the high bidder, and must not both
 * lock a stake against a bid only one of them holds. Firestore retries a
 * contended transaction automatically; two separate writes would give you two
 * winners and two stakes.
 */

import { getFirestore, FieldValue, Timestamp, Transaction } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

import { extendedEnd, minimumBidFor } from "./auctions";
import { maxBidFor, stakeFor } from "./credits";

const region = "europe-west2";

/** Fetched per call so a test can initialise the Admin SDK itself. */
const db = () => getFirestore();

export interface PlaceBidResult {
  bidId: string;
  amount: number;
  stakeLocked: number;
  /** Milliseconds since the epoch — the client turns this into a countdown. */
  endsAt: number;
  /** True when this bid pushed the closing time out. */
  extended: boolean;
}

/**
 * Validates and records one bid.
 *
 * Exported separately from the callable so the tests can drive it directly:
 * the wrapper's only job is to unpack a request and turn a thrown error into
 * an `HttpsError`.
 *
 * Every refusal is an `HttpsError` with a code the app can branch on, and a
 * message written to be shown as-is — a bidder who is told "invalid argument"
 * has learned nothing about what to do next.
 */
export async function placeBid(
  bidderId: string,
  auctionId: string,
  amount: number,
  now = new Date(),
): Promise<PlaceBidResult> {
  if (!Number.isInteger(amount) || amount < 1) {
    throw new HttpsError("invalid-argument", "Bid in whole pounds.");
  }

  const auctionRef = db().collection("auctions").doc(auctionId);
  const bidderRef = db().collection("users").doc(bidderId);
  const activeBids = auctionRef.collection("bids").where("status", "==", "active");
  const newBidRef = auctionRef.collection("bids").doc();

  return db().runTransaction(async (tx: Transaction) => {
    // ── reads ──

    const [auctionSnap, bidderSnap, activeSnap] = await Promise.all([
      tx.get(auctionRef),
      tx.get(bidderRef),
      tx.get(activeBids),
    ]);

    if (!auctionSnap.exists) {
      throw new HttpsError("not-found", "That auction is no longer here.");
    }

    const auction = auctionSnap.data() ?? {};

    if (auction.status !== "live") {
      throw new HttpsError("failed-precondition", "Bidding has closed on this one.");
    }

    // The closer runs once a minute, so an auction can be past its time and
    // still say live. The clock decides, not the status.
    const endsAt = auction.endsAt as Timestamp | undefined;
    const endsAtMs = endsAt ? endsAt.toMillis() : 0;
    if (endsAtMs <= now.getTime()) {
      throw new HttpsError("failed-precondition", "Bidding has closed on this one.");
    }

    // A seller bidding on their own item is shill bidding — the oldest way to
    // rig an auction, and the cheapest one to make impossible.
    if (auction.sellerId === bidderId) {
      throw new HttpsError(
        "permission-denied",
        "You can't bid on something you're selling.",
      );
    }

    if (!bidderSnap.exists) {
      throw new HttpsError("not-found", "Your profile is missing.");
    }

    const bidder = bidderSnap.data() ?? {};

    if (bidder.isSuspended === true) {
      throw new HttpsError("permission-denied", "Suspended accounts can't bid.");
    }

    const currentBid =
      typeof auction.currentBid === "number" ? auction.currentBid : null;
    const currentBidderId =
      typeof auction.currentBidderId === "string" ? auction.currentBidderId : null;

    // Bidding against yourself only locks more credits for the same position.
    if (currentBidderId === bidderId) {
      throw new HttpsError(
        "failed-precondition",
        "You're already the highest bidder.",
      );
    }

    const startPrice = typeof auction.startPrice === "number" ? auction.startPrice : 0;
    const minimum = minimumBidFor(startPrice, currentBid);
    if (amount < minimum) {
      throw new HttpsError(
        "failed-precondition",
        `The next bid has to be at least £${minimum}.`,
      );
    }

    const credits = typeof bidder.credits === "number" ? bidder.credits : 0;
    const locked = typeof bidder.creditsLocked === "number" ? bidder.creditsLocked : 0;
    const available = Math.max(0, credits - locked);

    const ceiling = maxBidFor(available);
    if (amount > ceiling) {
      throw new HttpsError(
        "failed-precondition",
        `You can bid up to £${ceiling} right now. Complete more deals to raise it.`,
      );
    }

    const stake = stakeFor(amount);
    if (stake > available) {
      throw new HttpsError(
        "failed-precondition",
        `That bid holds ${stake} credits and you have ${available} free.`,
      );
    }

    // Everyone still standing loses their hold — in practice one bidder, but
    // the release is written from what is actually there rather than from what
    // the auction document claims.
    const releasing = activeSnap.docs.filter(
      (doc) => doc.data().bidderId !== bidderId,
    );

    const releasedRefs = [
      ...new Set(
        releasing
          .map((doc) => doc.data().bidderId)
          .filter((id): id is string => typeof id === "string"),
      ),
    ].map((id) => db().collection("users").doc(id));

    const releasedSnaps = releasedRefs.length ? await tx.getAll(...releasedRefs) : [];

    // ── writes ──

    const released = new Map<string, number>();
    for (const doc of releasing) {
      const previous = doc.data();
      const stakeHeld =
        typeof previous.stakeLocked === "number" ? previous.stakeLocked : 0;

      tx.update(doc.ref, {
        status: "outbid",
        releasedAt: FieldValue.serverTimestamp(),
      });

      if (typeof previous.bidderId === "string" && stakeHeld > 0) {
        released.set(
          previous.bidderId,
          (released.get(previous.bidderId) ?? 0) + stakeHeld,
        );
      }
    }

    for (const snap of releasedSnaps) {
      if (!snap.exists) continue;

      const give = released.get(snap.id) ?? 0;
      if (give === 0) continue;

      const held = snap.get("creditsLocked");
      const current = typeof held === "number" ? held : 0;
      tx.update(snap.ref, { creditsLocked: Math.max(0, current - give) });
    }

    tx.set(newBidRef, {
      bidderId,
      // Denormalised so bid history doesn't need a profile read per row.
      bidderName: typeof bidder.fullName === "string" ? bidder.fullName : "Student",
      amount,
      stakeLocked: stake,
      status: "active",
      placedAt: FieldValue.serverTimestamp(),
    });

    tx.update(bidderRef, { creditsLocked: locked + stake });

    const extensions =
      typeof auction.extensionsMs === "number" ? auction.extensionsMs : 0;
    const moved = extendedEnd(endsAtMs, extensions, now.getTime());
    const extended = moved.endsAtMs !== endsAtMs;

    tx.update(auctionRef, {
      currentBid: amount,
      currentBidderId: bidderId,
      bidCount: FieldValue.increment(1),
      ...(extended
        ? {
            endsAt: Timestamp.fromMillis(moved.endsAtMs),
            extensionsMs: moved.extensionsMs,
          }
        : {}),
    });

    return {
      bidId: newBidRef.id,
      amount,
      stakeLocked: stake,
      endsAt: moved.endsAtMs,
      extended,
    };
  });
}

/**
 * The one thing a client is allowed to ask for.
 *
 * Note what it does not accept: a stake, a closing time, a bidder id. Those
 * are the server's to decide, and a callable that took them would be the
 * client writing the auction with extra steps.
 */
export const placeBidCallable = onCall({ region }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to bid.");
  }

  const auctionId = request.data?.auctionId;
  const amount = request.data?.amount;

  if (typeof auctionId !== "string" || auctionId.length === 0) {
    throw new HttpsError("invalid-argument", "Which auction?");
  }
  if (typeof amount !== "number") {
    throw new HttpsError("invalid-argument", "How much?");
  }

  const result = await placeBid(request.auth.uid, auctionId, amount);

  logger.info("Bid placed", {
    auctionId,
    bidderId: request.auth.uid,
    amount: result.amount,
    extended: result.extended,
  });

  return result;
});
