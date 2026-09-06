/**
 * Push notifications.
 *
 * An auction without "you've been outbid" is a feature people use once: the
 * whole point of bidding early is that you find out when somebody beats you,
 * and without that the only winning strategy is to sit on the page.
 *
 * Every send here is a side effect of something that already happened, so
 * none of them runs inside a transaction — a network call in a transaction is
 * retried along with the transaction, which would send the same push several
 * times. They run after the write commits, and a failure to notify is logged
 * rather than thrown: a bid that landed has landed, whether or not the loser's
 * phone was reachable.
 */

import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";

const db = () => getFirestore();

/**
 * Where a notification takes you when tapped.
 *
 * Sent as `data`, not as part of the visible notification, because the app
 * routes on it — see `NotificationsRepository` on the client.
 */
export interface NotificationRoute {
  /** `auction` or `chat`. */
  kind: string;
  id: string;
}

/**
 * Sends one notification to every device a member has registered.
 *
 * Tokens live in `users/{uid}/devices/{token}`. A token the FCM service
 * rejects as unregistered is deleted here rather than left to rot: an
 * uninstalled app leaves its token behind forever, and a member who has
 * reinstalled twice would otherwise cost three sends for every notification.
 */
export async function notify(
  uid: string,
  title: string,
  body: string,
  route: NotificationRoute,
): Promise<number> {
  const devices = await db().collection("users").doc(uid).collection("devices").get();
  const tokens = devices.docs.map((doc) => doc.id);
  if (tokens.length === 0) return 0;

  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { kind: route.kind, id: route.id },
      // No channelId on purpose. Android 8+ drops a notification whose
      // channel does not exist, and creating one needs native code the app
      // does not otherwise have. The Firebase SDK creates a default channel
      // by itself, so leaving this out is the difference between a plain
      // notification and no notification.
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });

    const stale: string[] = [];
    response.responses.forEach((result, index) => {
      const code = result.error?.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        stale.push(tokens[index]);
      }
    });

    await Promise.all(
      stale.map((token) =>
        db().collection("users").doc(uid).collection("devices").doc(token).delete(),
      ),
    );

    return response.successCount;
  } catch (error) {
    // Never fatal. The thing being announced already happened.
    logger.error("Could not send a notification", { uid, title, error });
    return 0;
  }
}

/** Records a device token. Called by the client through a callable. */
export async function registerDevice(
  uid: string,
  token: string,
  platform: string,
): Promise<void> {
  await db()
    .collection("users")
    .doc(uid)
    .collection("devices")
    .doc(token)
    .set({ platform, updatedAt: FieldValue.serverTimestamp() });
}

// ─────────────────────────────────────────────────── the four that matter

/**
 * Somebody went higher.
 *
 * The one notification the feature genuinely cannot do without. It carries the
 * new price so the decision — bid again or let it go — can be made from the
 * lock screen.
 */
export function notifyOutbid(
  bidderId: string,
  auctionId: string,
  title: string,
  newBid: number,
): Promise<number> {
  return notify(
    bidderId,
    "You've been outbid",
    `${title} is now at £${newBid}. Your credits are already back.`,
    { kind: "auction", id: auctionId },
  );
}

/** It's yours — and here is where the deal is waiting. */
export function notifyWon(
  winnerId: string,
  auctionId: string,
  title: string,
  price: number,
): Promise<number> {
  return notify(
    winnerId,
    "You won",
    `${title} is yours at £${price}. The deal is waiting in your chat.`,
    { kind: "auction", id: auctionId },
  );
}

/** How a seller's floor ended, in the words that matter to them. */
export function notifyAuctionClosed(
  sellerId: string,
  auctionId: string,
  title: string,
  outcome: "ended_sold" | "ended_unsold",
  price: number | null,
  reserveMet: boolean,
): Promise<number> {
  if (outcome === "ended_sold") {
    return notify(
      sellerId,
      "Your auction sold",
      `${title} went for £${price}. Arrange a meet in your chat.`,
      { kind: "auction", id: auctionId },
    );
  }

  return notify(
    sellerId,
    "Your auction closed",
    reserveMet
      ? `${title} closed with nobody bidding. You can list it again.`
      : `${title} closed under your reserve, so nothing sold.`,
    { kind: "auction", id: auctionId },
  );
}

/** The winner vanished; the item is offered on at the runner-up's own bid. */
export function notifyRunnerUp(
  runnerUpId: string,
  auctionId: string,
  title: string,
  bid: number,
): Promise<number> {
  return notify(
    runnerUpId,
    "It's yours if you still want it",
    `The winner of ${title} never turned up. It's yours at your bid of £${bid}.`,
    { kind: "auction", id: auctionId },
  );
}
