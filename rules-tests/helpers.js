import { readFileSync } from "node:fs";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";

/**
 * Shared setup for the rules suites.
 *
 * Both rules files are loaded straight from the repo root, so these tests
 * always run against what would actually be deployed.
 */

export const PROJECT_ID = "studyswap-rules-test";

export async function createTestEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: readFileSync(new URL("../storage.rules", import.meta.url), "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
}

/** A user document in the exact shape `firestore.rules` accepts on create. */
export function validUserDoc(overrides = {}) {
  return {
    fullName: "Amina Khan",
    email: "amina@uni.ac.uk",
    university: "none",
    rating: 0,
    ratingCount: 0,
    dealCount: 0,
    title: "Freshman Trader",
    credits: 50,
    creditsLocked: 0,
    role: "user",
    createdAt: new Date(),
    ...overrides,
  };
}

/** A listing document owned by [userId]. */
export function validListing(userId, overrides = {}) {
  return {
    title: "Campbell Biology 12th Edition",
    description: "Light highlighting in chapter 3.",
    price: 24.5,
    category: "textbooks",
    condition: "good",
    university: "Oxford",
    userId,
    sellerName: "Amina",
    imageUrls: [],
    status: "active",
    createdAt: new Date(),
    ...overrides,
  };
}

/** The chat id the app derives for a pair — the rules require exactly this. */
export function chatIdFor(a, b) {
  return [a, b].sort().join("_");
}

export function validChat(a, b, overrides = {}) {
  const participants = [a, b].sort();
  return {
    participants,
    participantNames: { [a]: "Amina", [b]: "Ben" },
    unreadCount: { [a]: 0, [b]: 0 },
    lastMessage: "",
    lastTimestamp: new Date(),
    createdAt: new Date(),
    ...overrides,
  };
}

export function validDealMessage(buyerId, sellerId, overrides = {}) {
  return {
    senderId: buyerId,
    receiverId: sellerId,
    type: "deal",
    text: "Deal Request for Campbell Biology",
    timestamp: new Date(),
    dealData: {
      itemId: "listing-1",
      title: "Campbell Biology",
      price: 24.5,
      status: "pending",
      buyerId,
      sellerId,
      createdAt: new Date(),
    },
    ...overrides,
  };
}

/** Mirrors `Review.idFor` in Dart and the id check in the rules. */
export function reviewId(chatId, fromId, toId) {
  return `review_${chatId}_${fromId}_${toId}`;
}

export function validReview(fromId, toId, chatId, overrides = {}) {
  return {
    fromId,
    toId,
    rating: 5,
    comment: "Smooth handover.",
    chatId,
    timestamp: new Date(),
    ...overrides,
  };
}

export function validReport(reporterId, overrides = {}) {
  return {
    reporterId,
    targetId: "listing-1",
    targetType: "listing",
    reason: "Prohibited Item",
    additionalNote: "",
    status: "pending",
    createdAt: new Date(),
    ...overrides,
  };
}

/**
 * An auction document, in the shape the closer writes.
 *
 * No client can write one, so there is no "valid on create" shape to mirror —
 * this exists purely so tests can seed a floor past the rules and then check
 * that nobody can touch it.
 */
export function validAuction(sellerId, overrides = {}) {
  return {
    listingId: "listing-1",
    listingTitle: "Signed rugby ball",
    listingImage: "",
    sellerId,
    sellerName: "Amina Khan",
    startPrice: 20,
    currentBid: null,
    currentBidderId: null,
    bidCount: 0,
    status: "live",
    endsAt: new Date(Date.now() + 60 * 60 * 1000),
    extensionsMs: 0,
    hasReserve: false,
    createdAt: new Date(),
    ...overrides,
  };
}

export function validBid(bidderId, amount, overrides = {}) {
  return {
    bidderId,
    bidderName: "Ben Ito",
    amount,
    stakeLocked: Math.ceil(amount / 10),
    status: "active",
    placedAt: new Date(),
    ...overrides,
  };
}
