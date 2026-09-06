/**
 * The handoff: where an auction stops being an auction.
 *
 * This is the integration the whole feature was designed around. A win does
 * not open a bespoke "you won" flow — it opens the ordinary chat between the
 * two of them and drops in the ordinary deal card, already accepted at the
 * winning price. From there it is a StudySwap deal like any other: they
 * arrange a meet, the seller marks it complete, `onDealCompleted` moves both
 * reputations, and they rate each other.
 *
 * Nothing about completing a trade is reinvented here, which is most of why
 * the auction was affordable to build at all.
 */

import {
  getFirestore,
  FieldValue,
  Timestamp,
  Transaction,
  DocumentSnapshot,
} from "firebase-admin/firestore";

const db = () => getFirestore();

/**
 * The chat id for a pair.
 *
 * Mirrors `ChatRepository.getOrCreateChat` and the id check in
 * `firestore.rules`: sorted uids joined by an underscore, so whoever starts
 * the conversation lands on the same document.
 */
export function chatIdFor(a: string, b: string): string {
  return [a, b].sort().join("_");
}

interface HandoffInput {
  auctionId: string;
  auction: FirebaseFirestore.DocumentData;
  buyerId: string;
  price: number;
  /** Text for the chat's last-message line. */
  summary: string;
}

/**
 * Writes the chat and the accepted deal for a handoff, inside [tx].
 *
 * Takes the transaction rather than opening its own so the deal card and the
 * auction's closing land together: a winner told they won with no deal in
 * their chat has nowhere to go.
 *
 * The chat may already exist — these two may have traded before — so its
 * snapshot is read by the caller and passed in. Firestore requires every read
 * before the first write, which is why this cannot fetch it itself.
 */
export function writeHandoff(
  tx: Transaction,
  chatSnap: DocumentSnapshot,
  { auctionId, auction, buyerId, price, summary }: HandoffInput,
): { chatId: string } {
  const sellerId = auction.sellerId as string;
  const chatId = chatSnap.id;
  const now = FieldValue.serverTimestamp();

  const title =
    typeof auction.listingTitle === "string" ? auction.listingTitle : "Item";

  if (!chatSnap.exists) {
    tx.set(chatSnap.ref, {
      participants: [buyerId, sellerId].sort(),
      participantNames: {
        [sellerId]:
          typeof auction.sellerName === "string" ? auction.sellerName : "Student",
        // Filled in by whichever of them opens the chat first; the app falls
        // back to "Student" rather than showing a blank name.
        [buyerId]: "Student",
      },
      unreadCount: { [buyerId]: 0, [sellerId]: 0 },
      lastMessage: "",
      lastTimestamp: now,
      createdAt: now,
    });
  }

  // A system line, so the chat says where the deal came from. Sent from the
  // seller so it reads as their side offering it.
  tx.set(chatSnap.ref.collection("messages").doc(), {
    senderId: sellerId,
    receiverId: buyerId,
    type: "deal",
    text: summary,
    timestamp: now,
    dealData: {
      itemId: typeof auction.listingId === "string" ? auction.listingId : "",
      title,
      price,
      // Already accepted: the bid *was* the agreement, and asking the seller
      // to accept a deal the auction already decided would be theatre.
      status: "accepted",
      buyerId,
      sellerId,
      // The link back, so settlement can find the auction from the deal.
      auctionId,
      createdAt: now,
    },
  });

  tx.update(chatSnap.ref, {
    lastMessage: summary,
    lastTimestamp: now,
    lastSenderId: sellerId,
    [`unreadCount.${buyerId}`]: FieldValue.increment(1),
  });

  return { chatId };
}

/**
 * Settles a completed auction deal.
 *
 * Called from `onDealCompleted` when the completed deal carries an
 * `auctionId`. The winner turned up, so their stake goes back and the auction
 * is done. The deal credits and reputation are handled by the same trigger
 * that handles every other deal — this only unwinds what the auction held.
 */
export async function settleCompletedAuction(
  auctionId: string,
  winnerId: string,
): Promise<void> {
  const auctionRef = db().collection("auctions").doc(auctionId);
  const winnerRef = db().collection("users").doc(winnerId);

  await db().runTransaction(async (tx: Transaction) => {
    const [auctionSnap, winnerSnap] = await Promise.all([
      tx.get(auctionRef),
      tx.get(winnerRef),
    ]);

    if (!auctionSnap.exists) return;

    const auction = auctionSnap.data() ?? {};
    // Only a sold auction has a stake left to release. A second completion
    // event — and Firestore triggers can fire more than once — finds it
    // already settled and does nothing.
    if (auction.status !== "ended_sold") return;

    const wonBids = await tx.get(
      auctionRef.collection("bids").where("status", "==", "won"),
    );

    let released = 0;
    for (const doc of wonBids.docs) {
      const stake = doc.data().stakeLocked;
      if (typeof stake === "number") released += stake;
      tx.update(doc.ref, { status: "settled" });
    }

    if (winnerSnap.exists && released > 0) {
      const locked = winnerSnap.get("creditsLocked");
      const current = typeof locked === "number" ? locked : 0;
      tx.update(winnerRef, { creditsLocked: Math.max(0, current - released) });
    }

    tx.update(auctionRef, {
      status: "settled",
      settledAt: FieldValue.serverTimestamp(),
    });
  });
}

/**
 * Takes the stake off a winner who never turned up, and offers the item on.
 *
 * The forfeit is the entire deterrent: without it, winning costs nothing and
 * bidding high costs nothing, which is how you end up with an auction full of
 * people who never meant to buy anything.
 *
 * The runner-up is then offered the item at their own bid. They are *not*
 * charged a new stake — they were released when they were outbid and never
 * agreed to stake again — so this is a courtesy offer rather than a second
 * binding win. Declining it costs them nothing.
 */
export interface ForfeitResult {
  forfeited: number;
  runnerUpId: string | null;
  runnerUpBid: number | null;
  listingTitle: string | null;
}

export async function forfeitAbandonedAuction(
  auctionId: string,
): Promise<ForfeitResult> {
  const auctionRef = db().collection("auctions").doc(auctionId);

  return db().runTransaction(async (tx: Transaction) => {
    const auctionSnap = await tx.get(auctionRef);
    if (!auctionSnap.exists) return { forfeited: 0, runnerUpId: null, runnerUpBid: null, listingTitle: null };

    const auction = auctionSnap.data() ?? {};
    if (auction.status !== "ended_sold") {
      return {
        forfeited: 0,
        runnerUpId: null,
        runnerUpBid: null,
        listingTitle: null,
      };
    }

    const winnerId = auction.winnerId as string | undefined;
    const sellerId = auction.sellerId as string | undefined;
    if (!winnerId || !sellerId) return { forfeited: 0, runnerUpId: null, runnerUpBid: null, listingTitle: null };

    const bidsSnap = await tx.get(
      auctionRef.collection("bids").orderBy("amount", "desc"),
    );

    const wonBid = bidsSnap.docs.find((doc) => doc.data().status === "won");
    const stake =
      typeof wonBid?.data().stakeLocked === "number"
        ? (wonBid.data().stakeLocked as number)
        : 0;

    // The best bid from anybody other than the winner.
    const runnerUp = bidsSnap.docs.find(
      (doc) => doc.data().bidderId !== winnerId,
    );
    const runnerUpId =
      typeof runnerUp?.data().bidderId === "string"
        ? (runnerUp.data().bidderId as string)
        : null;
    const runnerUpBid =
      typeof runnerUp?.data().amount === "number"
        ? (runnerUp.data().amount as number)
        : null;

    const winnerRef = db().collection("users").doc(winnerId);
    const sellerRef = db().collection("users").doc(sellerId);
    const chatRef =
      runnerUpId === null
        ? null
        : db().collection("chats").doc(chatIdFor(runnerUpId, sellerId));

    const [winnerSnap, sellerSnap, chatSnap] = await Promise.all([
      tx.get(winnerRef),
      tx.get(sellerRef),
      chatRef ? tx.get(chatRef) : Promise.resolve(null),
    ]);

    // ── writes ──

    if (wonBid) tx.update(wonBid.ref, { status: "forfeited" });

    if (winnerSnap.exists && stake > 0) {
      const credits = winnerSnap.get("credits");
      const locked = winnerSnap.get("creditsLocked");
      tx.update(winnerRef, {
        // Both move: the stake leaves the balance and stops being held.
        credits: Math.max(0, (typeof credits === "number" ? credits : 0) - stake),
        creditsLocked: Math.max(
          0,
          (typeof locked === "number" ? locked : 0) - stake,
        ),
      });
    }

    if (sellerSnap.exists && stake > 0) {
      const credits = sellerSnap.get("credits");
      tx.update(sellerRef, {
        credits: (typeof credits === "number" ? credits : 0) + stake,
      });
    }

    let handedTo: string | null = null;
    if (chatSnap && runnerUpId && runnerUpBid !== null) {
      writeHandoff(tx, chatSnap, {
        auctionId,
        auction,
        buyerId: runnerUpId,
        price: runnerUpBid,
        summary:
          `The winner of "${auction.listingTitle}" never turned up. ` +
          `It's yours at your bid of £${runnerUpBid} if you still want it.`,
      });
      handedTo = runnerUpId;
    }

    tx.update(auctionRef, {
      status: "abandoned",
      abandonedAt: FieldValue.serverTimestamp(),
      forfeitedCredits: stake,
      runnerUpId: runnerUpId,
      runnerUpBid: runnerUpBid,
      ...(handedTo ? { chatId: chatIdFor(handedTo, sellerId) } : {}),
    });

    return {
      forfeited: stake,
      runnerUpId,
      runnerUpBid,
      listingTitle:
        typeof auction.listingTitle === "string" ? auction.listingTitle : null,
    };
  });
}

/** How long a winner has to complete before the stake goes to the seller. */
export const ABANDON_AFTER_MS = 48 * 60 * 60 * 1000;

/** Auctions sold longer ago than [ABANDON_AFTER_MS] and never completed. */
export async function findAbandonedAuctions(
  now = new Date(),
  limit = 50,
): Promise<string[]> {
  const cutoff = Timestamp.fromMillis(now.getTime() - ABANDON_AFTER_MS);

  const snap = await db()
    .collection("auctions")
    .where("status", "==", "ended_sold")
    .where("endedAt", "<=", cutoff)
    .orderBy("endedAt")
    .limit(limit)
    .get();

  return snap.docs.map((doc) => doc.id);
}
