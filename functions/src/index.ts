/**
 * StudySwap Cloud Functions.
 *
 * Everything here exists because a client shouldn't be trusted to write it.
 * Ratings, deal counts and reputation titles used to be computed in a
 * Firestore transaction on the user's device, which meant anyone could hand
 * themselves a 5.0 average and the top badge with a single write. Those fields
 * are now denied to every client in `firestore.rules` and owned by the
 * triggers below.
 *
 * Credits belong to the same category and for a sharper reason: they are what
 * a bid costs, so a client that could write its own balance could bid any
 * number it liked. See `credits.ts`.
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore, Transaction } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getAuth } from "firebase-admin/auth";
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

import { CREDITS, creditsForReview } from "./credits";

// The auction floor: the function that closes it, and the one thing a client
// is allowed to ask for. Re-exported so Firebase finds them — only what the
// entry point exports gets deployed.
export { closeExpiredAuctions, createAuctionCallable } from "./auctions";
export { placeBidCallable } from "./bids";

initializeApp();

const db = getFirestore();

/** Keep every function in one region so they share a cold-start pool. */
const region = "europe-west2";

/**
 * Reputation titles by completed deal count.
 *
 * This is the only definition. The Dart client used to carry a copy and so did
 * `firestore.rules`; both are gone now that no client can write the field.
 */
function titleForDeals(deals: number): string {
  if (deals >= 31) return "Campus Pro";
  if (deals >= 16) return "Deal Maker";
  if (deals >= 8) return "Trade Regular";
  if (deals >= 3) return "Campus Seller";
  return "Freshman Trader";
}

// ─────────────────────────────────────────────────────────── ratings

/**
 * Recomputes a member's average rating when they receive a review.
 *
 * Runs in a transaction so two reviews landing at once can't lose an update.
 * The client writes only the review document; `reviews` has a deterministic id
 * and is create-only, so one review per deal per direction is already enforced
 * by the rules.
 */
export const onReviewCreated = onDocumentCreated(
  { document: "reviews/{reviewId}", region },
  async (event) => {
    const review = event.data?.data();
    if (!review) return;

    const toId = review.toId as string | undefined;
    const rating = review.rating as number | undefined;

    if (!toId || typeof rating !== "number") {
      logger.warn("Malformed review, skipping", { reviewId: event.params.reviewId });
      return;
    }

    const clamped = Math.min(5, Math.max(1, rating));
    const userRef = db.collection("users").doc(toId);

    await db.runTransaction(async (tx: Transaction) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) return;

      const data = snap.data() ?? {};
      const currentAverage = typeof data.rating === "number" ? data.rating : 0;
      const currentCount = typeof data.ratingCount === "number" ? data.ratingCount : 0;

      const nextCount = currentCount + 1;
      const nextAverage = (currentAverage * currentCount + clamped) / nextCount;

      // A good review is worth bidding power. Awarded in the same transaction
      // as the average so a member can never end up rated but uncredited.
      const award = creditsForReview(clamped);
      const currentCredits = typeof data.credits === "number" ? data.credits : 0;

      tx.update(userRef, {
        rating: nextAverage,
        ratingCount: nextCount,
        credits: currentCredits + award,
      });
    });

    logger.info("Rating aggregate updated", { toId });
  }
);

// ─────────────────────────────────────────────────────────── deals

/**
 * Settles a deal when the seller marks it complete.
 *
 * The client only flips `dealData.status` on the message — the rules let the
 * seller do that and nothing else. Everything that follows from it (both
 * parties' deal counts, their titles, and marking the listing sold) happens
 * here, atomically.
 */
export const onDealCompleted = onDocumentUpdated(
  { document: "chats/{chatId}/messages/{messageId}", region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasCompleted = before.dealData?.status === "completed";
    const isCompleted = after.dealData?.status === "completed";

    // Only the pending/accepted → completed edge does anything.
    if (wasCompleted || !isCompleted) return;

    const deal = after.dealData as {
      buyerId?: string;
      sellerId?: string;
      itemId?: string;
    };

    if (!deal.buyerId || !deal.sellerId) {
      logger.warn("Completed deal missing participants", event.params);
      return;
    }

    const buyerRef = db.collection("users").doc(deal.buyerId);
    const sellerRef = db.collection("users").doc(deal.sellerId);
    const listingRef = deal.itemId
      ? db.collection("listings").doc(deal.itemId)
      : null;

    await db.runTransaction(async (tx: Transaction) => {
      // All reads first — Firestore transactions require it.
      const [buyerSnap, sellerSnap] = await Promise.all([
        tx.get(buyerRef),
        tx.get(sellerRef),
      ]);

      // The seller's award is larger: they carry more of a handover's risk.
      for (const [ref, snap, award] of [
        [buyerRef, buyerSnap, CREDITS.buyerCompletion],
        [sellerRef, sellerSnap, CREDITS.sellerCompletion],
      ] as const) {
        if (!snap.exists) continue;

        const data = snap.data() ?? {};
        const current = typeof data.dealCount === "number" ? data.dealCount : 0;
        const credits = typeof data.credits === "number" ? data.credits : 0;
        const next = current + 1;

        tx.update(ref, {
          dealCount: next,
          title: titleForDeals(next),
          credits: credits + award,
        });
      }

      if (listingRef) {
        tx.set(listingRef, { status: "sold" }, { merge: true });
      }
    });

    logger.info("Deal settled", {
      chatId: event.params.chatId,
      buyerId: deal.buyerId,
      sellerId: deal.sellerId,
    });
  }
);

// ─────────────────────────────────────────────────────────── storage

/**
 * Removes a listing's photos when the listing goes.
 *
 * Doing this server-side means the files are cleaned up even if the app was
 * killed mid-delete, and it lets the client stop tracking how many images a
 * listing had just to delete them.
 */
export const onListingDeleted = onDocumentDeleted(
  { document: "listings/{listingId}", region },
  async (event) => {
    const listing = event.data?.data();
    const ownerId = listing?.userId as string | undefined;
    if (!ownerId) return;

    const prefix = `listings/${ownerId}/${event.params.listingId}/`;

    try {
      await getStorage().bucket().deleteFiles({ prefix });
      logger.info("Listing images removed", { prefix });
    } catch (error) {
      // A listing with no photos has no folder; that isn't a failure.
      logger.warn("Could not remove listing images", { prefix, error });
    }
  }
);

// ─────────────────────────────────────────────────────────── moderation

/**
 * Grants or revokes the moderator claim.
 *
 * Moderator status is an auth custom claim rather than a Firestore field
 * precisely so a client can't set it — which means it can't be set from the
 * app at all. Only an existing moderator can call this.
 *
 * Bootstrapping the first moderator has to happen outside the app. From a
 * trusted machine with Admin SDK credentials:
 *
 *   admin.auth().setCustomUserClaims('<uid>', { role: 'moderator' })
 *
 * The user must sign out and back in for a new claim to reach their token.
 */
export const setModeratorRole = onCall({ region }, async (request) => {
  if (request.auth?.token.role !== "moderator") {
    throw new HttpsError(
      "permission-denied",
      "Only a moderator can change moderator access."
    );
  }

  const uid = request.data?.uid;
  const grant = request.data?.grant;

  if (typeof uid !== "string" || uid.length === 0) {
    throw new HttpsError("invalid-argument", "A user id is required.");
  }
  if (typeof grant !== "boolean") {
    throw new HttpsError("invalid-argument", "`grant` must be true or false.");
  }
  if (uid === request.auth.uid && !grant) {
    throw new HttpsError(
      "failed-precondition",
      "You can't revoke your own moderator access."
    );
  }

  await getAuth().setCustomUserClaims(uid, grant ? { role: "moderator" } : {});
  // Descriptive only; authorization reads the claim, not this field.
  await db.collection("users").doc(uid).set(
    { role: grant ? "moderator" : "user" },
    { merge: true }
  );

  logger.info("Moderator role changed", { uid, grant, by: request.auth.uid });
  return { uid, grant };
});

// ─────────────────────────────────────────────────────────── suspension

/**
 * Disables the Auth account when a moderator suspends a member.
 *
 * `firestore.rules` already blocks a suspended account's writes, but until the
 * Auth account itself is disabled they keep a valid token and can still read.
 */
export const onSuspensionChanged = onDocumentUpdated(
  { document: "users/{userId}", region },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasSuspended = before.isSuspended === true;
    const isSuspended = after.isSuspended === true;
    if (wasSuspended === isSuspended) return;

    try {
      await getAuth().updateUser(event.params.userId, { disabled: isSuspended });
      logger.info("Auth account availability changed", {
        userId: event.params.userId,
        disabled: isSuspended,
      });
    } catch (error) {
      logger.error("Could not change Auth account availability", {
        userId: event.params.userId,
        error,
      });
    }
  }
);
