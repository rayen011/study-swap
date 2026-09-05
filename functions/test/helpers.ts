import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

/**
 * Shared setup for the Cloud Functions tests.
 *
 * These run against the real Firestore emulator with the real Admin SDK,
 * because the things worth testing here — a transaction that has to apply
 * whole or not at all, a query that needs a composite index — are precisely
 * the things a mocked Firestore would not tell the truth about.
 *
 * `FIRESTORE_EMULATOR_HOST` is what redirects the Admin SDK; the npm script
 * sets it by running under `firebase emulators:exec`.
 */

export const PROJECT_ID = "studyswap-functions-test";

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    "No Firestore emulator. Run these with `npm run test:emulate`, which " +
      "starts one — `npm test` alone would write to a real project.",
  );
}

if (getApps().length === 0) {
  initializeApp({ projectId: PROJECT_ID });
}

export const db = getFirestore();

/** Wipes every collection these tests touch, so each starts from nothing. */
export async function clearFirestore() {
  const response = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/` +
      `${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );

  if (!response.ok) {
    throw new Error(`Could not clear the emulator: ${response.status}`);
  }
}

interface AuctionSeed {
  sellerId: string;
  startPrice?: number;
  currentBid?: number | null;
  currentBidderId?: string | null;
  status?: string;
  /** Minutes from now. Negative means the auction is already overdue. */
  endsInMinutes?: number;
  reservePrice?: number;
  bids?: { bidderId: string; amount: number; stake: number; status?: string }[];
}

/**
 * Writes an auction, its private reserve and its bid history.
 *
 * Returns the auction id. Written with the Admin SDK, which bypasses the
 * security rules — the same way the callable that creates auctions will.
 */
export async function seedAuction(
  id: string,
  {
    sellerId,
    startPrice = 20,
    currentBid = null,
    currentBidderId = null,
    status = "live",
    endsInMinutes = -1,
    reservePrice,
    bids = [],
  }: AuctionSeed,
): Promise<string> {
  const ref = db.collection("auctions").doc(id);

  await ref.set({
    listingId: `listing-${id}`,
    listingTitle: "Signed rugby ball",
    listingImage: "",
    sellerId,
    sellerName: sellerId,
    startPrice,
    currentBid,
    currentBidderId,
    bidCount: bids.length,
    status,
    endsAt: new Date(Date.now() + endsInMinutes * 60_000),
    extensionsMs: 0,
    hasReserve: typeof reservePrice === "number",
    createdAt: new Date(),
  });

  if (typeof reservePrice === "number") {
    await ref.collection("private").doc("config").set({ reservePrice });
  }

  for (const [index, bid] of bids.entries()) {
    await ref.collection("bids").doc(`bid-${index}`).set({
      bidderId: bid.bidderId,
      bidderName: bid.bidderId,
      amount: bid.amount,
      stakeLocked: bid.stake,
      status: bid.status ?? "active",
      placedAt: new Date(),
    });
  }

  return id;
}

export async function seedUser(
  id: string,
  { credits = 100, creditsLocked = 0 } = {},
) {
  await db.collection("users").doc(id).set({
    fullName: id,
    email: `${id}@uni.ac.uk`,
    university: "none",
    rating: 0,
    ratingCount: 0,
    dealCount: 0,
    title: "Freshman Trader",
    credits,
    creditsLocked,
    role: "user",
    createdAt: new Date(),
  });
}

export async function readAuction(id: string) {
  return (await db.collection("auctions").doc(id).get()).data() ?? {};
}

export async function readUser(id: string) {
  return (await db.collection("users").doc(id).get()).data() ?? {};
}

export async function readBids(auctionId: string) {
  const snap = await db
    .collection("auctions")
    .doc(auctionId)
    .collection("bids")
    .get();

  return Object.fromEntries(snap.docs.map((doc) => [doc.id, doc.data()]));
}
