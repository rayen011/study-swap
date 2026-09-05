/**
 * Seeds a StudySwap project with demo data.
 *
 * Written for two reasons. One: the marketplace feed hides your own listings,
 * so a project with a single account shows an empty feed no matter how much
 * you post — you need other members before the app looks like anything.
 * Two: the README's screenshots need a populated feed, a chat with a deal in
 * it, and a profile with real reputation.
 *
 * Usage:
 *   1. Firebase console → Project settings → Service accounts →
 *      "Generate new private key". Save it as tools/serviceAccountKey.json.
 *      It is gitignored. Do not commit it.
 *   2. node tools/seed.mjs
 *
 * Flags:
 *   --wipe    remove the demo data, then seed it again
 *   --clean   remove the demo data and stop, leaving the project without it
 *
 * Only touches the demo accounts listed in DEMO_USERS. Your own account and
 * anything you created by hand are left alone.
 */

import { readFileSync } from "node:fs";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

import { creditsFromHistory } from "./credit-rules.mjs";

const KEY_PATH = new URL("./serviceAccountKey.json", import.meta.url);

let serviceAccount;
try {
  serviceAccount = JSON.parse(readFileSync(KEY_PATH, "utf8"));
} catch {
  console.error(
    "\nMissing tools/serviceAccountKey.json.\n\n" +
      "Firebase console → Project settings → Service accounts →\n" +
      '"Generate new private key", save it there, and run this again.\n',
  );
  process.exit(1);
}

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

// ── Demo members ─────────────────────────────────────────────────────────
// Fixed ids so re-running overwrites rather than duplicating, and prefixed so
// the wipe can find them without touching anything real.

const PREFIX = "demo_";

const DEMO_USERS = [
  {
    id: `${PREFIX}amina`,
    fullName: "Amina Khan",
    email: "amina@demo.studyswap",
    university: "University of Oxford",
    rating: 4.8,
    ratingCount: 12,
    dealCount: 17,
    title: "Deal Maker",
  },
  {
    id: `${PREFIX}ben`,
    fullName: "Ben Ito",
    email: "ben@demo.studyswap",
    university: "University of Oxford",
    rating: 4.3,
    ratingCount: 6,
    dealCount: 9,
    title: "Trade Regular",
  },
  {
    id: `${PREFIX}chloe`,
    fullName: "Chloe Martins",
    email: "chloe@demo.studyswap",
    university: "Oxford Brookes",
    rating: 5,
    ratingCount: 3,
    dealCount: 4,
    title: "Campus Seller",
  },
];

// Wire values, matching lib/core/constants/listing_options.dart.
const LISTINGS = [
  ["Campbell Biology, 12th Edition", "Light highlighting in the first three chapters, spine intact.", 24.5, "textbooks", "good", 0],
  ["Organic Chemistry as a Second Language", "Barely opened. Bought it, never used it.", 18, "textbooks", "like_new", 1],
  ["Atkins' Physical Chemistry", "Some pencil notes in the margins, all erasable.", 32, "textbooks", "fair", 2],
  ["Full year of Linear Algebra notes", "Handwritten, scanned to PDF, plus my worked exam solutions.", 12, "study_summaries", "like_new", 0],
  ["Thermodynamics revision pack", "Condensed 40 pages into 12. Got me a first.", 9.5, "study_summaries", "like_new", 1],
  ["Casio FX-991EX calculator", "Exam-approved. Cover included, no scratches.", 15, "electronics", "good", 2],
  ["Anglepoise desk lamp", "Warm bulb included. One small chip on the base.", 22, "electronics", "fair", 0],
  ["Second monitor, 24 inch", "1080p, HDMI cable included. Upgrading to ultrawide.", 65, "electronics", "good", 1],
  ["Lab coat, size M", "Washed, no stains. Chemistry department standard.", 8, "stationery", "good", 2],
  ["Pack of 12 lever arch files", "Never used, still shrink-wrapped.", 6.5, "stationery", "like_new", 0],
  ["Room in shared house, Cowley Road", "Double room, 10 min cycle to campus. Available from October.", 620, "housing", "good", 1],
  ["Bike with lock and lights", "Hybrid, recently serviced. Graduating, so it has to go.", 95, "other", "good", 2],
];

const cleanOnly = process.argv.includes("--clean");
const wipe = cleanOnly || process.argv.includes("--wipe");

/** Deletes documents in batches; Firestore caps a batch at 500 writes. */
async function deleteAll(query, label) {
  const snap = await query.get();
  if (snap.empty) return 0;

  for (let i = 0; i < snap.docs.length; i += 400) {
    const batch = db.batch();
    for (const doc of snap.docs.slice(i, i + 400)) batch.delete(doc.ref);
    await batch.commit();
  }
  console.log(`  removed ${snap.size} ${label}`);
  return snap.size;
}

async function wipeDemoData() {
  console.log("\nRemoving previous demo data…");
  const ids = DEMO_USERS.map((u) => u.id);

  await deleteAll(db.collection("listings").where("userId", "in", ids), "listings");
  await deleteAll(db.collection("reviews").where("toId", "in", ids), "reviews");

  const chats = await db.collection("chats").get();
  for (const chat of chats.docs) {
    if (!chat.id.startsWith(PREFIX)) continue;
    await deleteAll(chat.ref.collection("messages"), "messages");
    await chat.ref.delete();
  }

  const batch = db.batch();
  for (const id of ids) batch.delete(db.collection("users").doc(id));
  await batch.commit();
  console.log(`  removed ${ids.length} demo profiles`);
}

async function seedUsers() {
  const batch = db.batch();
  for (const user of DEMO_USERS) {
    const { id, ...data } = user;
    batch.set(db.collection("users").doc(id), {
      ...data,
      // Derived from the reputation above rather than picked, so the demo
      // members' balances tell the same story their profiles do.
      credits: creditsFromHistory(data),
      creditsLocked: 0,
      role: "user",
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Seeded ${DEMO_USERS.length} demo members`);
}

async function seedListings() {
  const ids = [];
  const batch = db.batch();

  LISTINGS.forEach(([title, description, price, category, condition, ownerIndex], i) => {
    const owner = DEMO_USERS[ownerIndex];
    const ref = db.collection("listings").doc();
    ids.push(ref.id);

    batch.set(ref, {
      title,
      description,
      price,
      category,
      condition,
      university: owner.university,
      userId: owner.id,
      sellerName: owner.fullName,
      imageUrls: [],
      // One sold listing so the Collection tab and profile aren't empty.
      status: i === LISTINGS.length - 1 ? "sold" : "active",
      // Staggered so "newest" sorting has something to order.
      createdAt: new Date(Date.now() - i * 3_600_000),
    });
  });

  await batch.commit();
  console.log(`Seeded ${LISTINGS.length} listings`);
  return ids;
}

/** A finished conversation, so the deal card and reviews have something to show. */
async function seedConversation(listingId) {
  const [amina, ben] = DEMO_USERS;
  const participants = [amina.id, ben.id].sort();
  const chatId = participants.join("_");
  const chatRef = db.collection("chats").doc(chatId);

  await chatRef.set({
    participants,
    participantNames: { [amina.id]: amina.fullName, [ben.id]: ben.fullName },
    unreadCount: { [amina.id]: 0, [ben.id]: 1 },
    lastMessage: "Perfect, see you at the library at 2.",
    lastSenderId: ben.id,
    lastTimestamp: new Date(),
    createdAt: new Date(Date.now() - 86_400_000),
  });

  const messages = chatRef.collection("messages");
  const t = (minsAgo) => new Date(Date.now() - minsAgo * 60_000);

  const batch = db.batch();
  batch.set(messages.doc(), {
    senderId: ben.id, receiverId: amina.id,
    text: "Hey — is the Campbell Biology still going?",
    timestamp: t(180),
  });
  batch.set(messages.doc(), {
    senderId: amina.id, receiverId: ben.id,
    text: "It is. Happy to meet on campus.",
    timestamp: t(170),
  });
  batch.set(messages.doc(), {
    senderId: ben.id, receiverId: amina.id,
    type: "deal",
    text: "Deal Request for Campbell Biology, 12th Edition",
    timestamp: t(160),
    dealData: {
      itemId: listingId,
      title: "Campbell Biology, 12th Edition",
      price: 24.5,
      status: "completed",
      buyerId: ben.id,
      sellerId: amina.id,
      createdAt: t(160),
    },
  });
  batch.set(messages.doc(), {
    senderId: ben.id, receiverId: amina.id,
    text: "Perfect, see you at the library at 2.",
    timestamp: t(5),
  });
  await batch.commit();

  console.log("Seeded a conversation with a completed deal");
  return chatId;
}

async function seedReviews(chatId) {
  const [amina, ben] = DEMO_USERS;
  const id = (from, to) => `review_${chatId}_${from}_${to}`;

  const batch = db.batch();
  batch.set(db.collection("reviews").doc(id(ben.id, amina.id)), {
    fromId: ben.id, toId: amina.id, rating: 5,
    comment: "Exactly as described, and she waited when I was late. Smooth.",
    chatId, timestamp: new Date(Date.now() - 3_600_000),
  });
  batch.set(db.collection("reviews").doc(id(amina.id, ben.id)), {
    fromId: amina.id, toId: ben.id, rating: 4,
    comment: "Turned up, paid, no fuss. Would sell to again.",
    chatId, timestamp: new Date(Date.now() - 3_500_000),
  });
  await batch.commit();

  console.log("Seeded 2 reviews");
}

async function main() {
  console.log(`\nProject: ${serviceAccount.project_id}`);

  if (wipe) await wipeDemoData();

  if (cleanOnly) {
    console.log(
      "\nDemo data removed.\n\n" +
        "Your own account and anything you created by hand were left alone.\n" +
        "Run `npm --prefix tools run seed` to put the demo data back.\n",
    );
    return;
  }

  await seedUsers();
  const listingIds = await seedListings();
  const chatId = await seedConversation(listingIds[0]);
  await seedReviews(chatId);

  console.log(
    "\nDone.\n\n" +
      "Sign in with your own account and the feed will show these listings —\n" +
      "they belong to the demo members, so they aren't filtered out the way\n" +
      "your own listings are.\n\n" +
      "The demo members have no Auth accounts, so you can't sign in as them.\n" +
      "That's deliberate: the app only ever reads their profiles.\n\n" +
      "Re-run with --wipe to clear and reseed.\n",
  );
}

main().catch((error) => {
  console.error("\nSeeding failed:", error.message ?? error, "\n");
  process.exit(1);
});
