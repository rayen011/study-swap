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

// Things whose worth is genuinely hard to guess — which is the only kind of
// item the Bid Room is for.
//
// [title, description, opening price, ownerIndex, hours left, bids]
// Each bid is [bidderIndex, amount].
const AUCTIONS = [
  [
    "Signed university rugby ball",
    "Signed by the whole 2019 first team after the varsity match. No idea what it's worth.",
    10,
    0,
    0.03,
    [[1, 45], [2, 62], [1, 85]],
  ],
  [
    "Vintage college scarf, 1987",
    "Found it in my grandad's attic. The stripes are the old college colours.",
    8,
    2,
    27,
    [[0, 22], [1, 46]],
  ],
  [
    "Graduation gown and hood, size M",
    "Worn once. Cheaper than hiring one, if you're graduating this year.",
    15,
    1,
    5.2,
    [[2, 32]],
  ],
  [
    "Physics dept. lab coat, signed",
    "Signed by the department when they retired. Genuinely have no idea what to ask.",
    12,
    0,
    164,
    [],
  ],
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

  // Auctions go with their listings. Each one's bids and private reserve are
  // subcollections, so the parent has to be emptied before it is deleted.
  const auctions = await db.collection("auctions").where("sellerId", "in", ids).get();
  for (const auction of auctions.docs) {
    await deleteAll(auction.ref.collection("bids"), "bids");
    await deleteAll(auction.ref.collection("private"), "reserves");
    await auction.ref.delete();
  }
  if (auctions.size > 0) console.log(`  removed ${auctions.size} auctions`);

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

/**
 * Opens demo floors, with bids already on them.
 *
 * Written with the Admin SDK exactly as `createAuctionCallable` and
 * `placeBid` would — the reserve in the private subcollection, the stakes
 * held on the leading bidder, the beaten bids marked outbid. A room seeded
 * any other way would look right and behave wrongly the moment anybody bid.
 */
async function seedAuctions() {
  const batch = db.batch();
  let count = 0;

  for (const [title, description, startPrice, ownerIndex, hoursLeft, bids] of AUCTIONS) {
    const owner = DEMO_USERS[ownerIndex];

    const listingRef = db.collection("listings").doc();
    const auctionRef = db.collection("auctions").doc();

    const leading = bids.length ? bids[bids.length - 1] : null;
    const leadingBidder = leading ? DEMO_USERS[leading[0]] : null;

    batch.set(listingRef, {
      title,
      description,
      price: startPrice,
      category: "other",
      condition: "good",
      university: owner.university,
      userId: owner.id,
      sellerName: owner.fullName,
      imageUrls: [],
      status: "active",
      saleMode: "auction",
      auctionId: auctionRef.id,
      createdAt: new Date(Date.now() - 86_400_000),
    });

    batch.set(auctionRef, {
      listingId: listingRef.id,
      listingTitle: title,
      listingImage: "",
      sellerId: owner.id,
      sellerName: owner.fullName,
      startPrice,
      currentBid: leading ? leading[1] : null,
      currentBidderId: leadingBidder ? leadingBidder.id : null,
      bidCount: bids.length,
      status: "live",
      endsAt: new Date(Date.now() + hoursLeft * 3_600_000),
      extensionsMs: 0,
      // One of them has a reserve, so the badge has somewhere to show.
      hasReserve: title.startsWith("Signed university"),
      reserveMet: false,
      winnerId: null,
      winningBid: null,
      chatId: null,
      createdAt: new Date(Date.now() - 86_400_000),
    });

    if (title.startsWith("Signed university")) {
      batch.set(auctionRef.collection("private").doc("config"), {
        reservePrice: 120,
      });
    }

    bids.forEach(([bidderIndex, amount], i) => {
      const bidder = DEMO_USERS[bidderIndex];
      const isLeading = i === bids.length - 1;

      batch.set(auctionRef.collection("bids").doc(), {
        bidderId: bidder.id,
        bidderName: bidder.fullName,
        amount,
        stakeLocked: Math.ceil(amount / 10),
        // Only the top bid still holds credits. Everyone else got theirs
        // back the moment they were beaten.
        status: isLeading ? "active" : "outbid",
        placedAt: new Date(Date.now() - (bids.length - i) * 900_000),
      });
    });

    count++;
  }

  await batch.commit();
  console.log(`Seeded ${count} auctions`);
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
  await seedAuctions();
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
