import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";

import {
  chatIdFor,
  createTestEnv,
  reviewId,
  validChat,
  validDealMessage,
  validListing,
  validAuction,
  validBid,
  validReport,
  validReview,
  validUserDoc,
} from "./helpers.js";

const ALICE = "alice";
const BOB = "bob";
const MOD = "mod";

let testEnv;

/** Firestore as a signed-in member. */
const as = (uid, claims) => testEnv.authenticatedContext(uid, claims).firestore();
const asModerator = () => as(MOD, { role: "moderator" });
const asAnon = () => testEnv.unauthenticatedContext().firestore();

/** Writes past the rules, for arranging state a test needs. */
const seed = (fn) => testEnv.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

beforeAll(async () => {
  testEnv = await createTestEnv();
});

afterAll(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    await setDoc(doc(db, "users", ALICE), validUserDoc());
    await setDoc(doc(db, "users", BOB), validUserDoc({ fullName: "Ben Ito" }));
    await setDoc(doc(db, "users", MOD), validUserDoc({ fullName: "Mod" }));
  });
});

// ──────────────────────────────────────────────────────────────── users

describe("users", () => {
  test("any signed-in member can read a profile", async () => {
    await assertSucceeds(getDoc(doc(as(BOB), "users", ALICE)));
  });

  test("a signed-out visitor cannot", async () => {
    await assertFails(getDoc(doc(asAnon(), "users", ALICE)));
  });

  test("a new account starts with zeroed reputation", async () => {
    await assertSucceeds(
      setDoc(doc(as("newbie"), "users", "newbie"), validUserDoc()),
    );
  });

  test("cannot create a profile at somebody else's id", async () => {
    await assertFails(
      setDoc(doc(as("newbie"), "users", ALICE), validUserDoc()),
    );
  });

  test("cannot sign up as a moderator", async () => {
    await assertFails(
      setDoc(
        doc(as("newbie"), "users", "newbie"),
        validUserDoc({ role: "moderator" }),
      ),
    );
  });

  test("cannot sign up with reputation already earned", async () => {
    await assertFails(
      setDoc(
        doc(as("newbie"), "users", "newbie"),
        validUserDoc({ rating: 5, ratingCount: 40, dealCount: 40 }),
      ),
    );
  });

  test("cannot sign up with a bigger opening credit balance", async () => {
    // Credits are what a bid costs, so a self-written balance is a self-written
    // bid ceiling. The rules accept exactly one opening value.
    await assertFails(
      setDoc(
        doc(as("newbie"), "users", "newbie"),
        validUserDoc({ credits: 5000 }),
      ),
    );
  });

  test("cannot sign up with credits already staked", async () => {
    await assertFails(
      setDoc(
        doc(as("newbie"), "users", "newbie"),
        validUserDoc({ creditsLocked: 25 }),
      ),
    );
  });

  test("cannot smuggle an extra field into a new profile", async () => {
    await assertFails(
      setDoc(
        doc(as("newbie"), "users", "newbie"),
        validUserDoc({ isSuspended: false }),
      ),
    );
  });

  test("the owner can edit their name and university", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), "users", ALICE), {
        fullName: "Amina K",
        university: "Oxford",
      }),
    );
  });

  test("nobody can edit somebody else's profile", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "users", ALICE), { fullName: "Hacked" }),
    );
  });

  // The heart of step 7: these four used to be writable by a client.
  test("a user cannot write their own rating", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "users", ALICE), { rating: 5, ratingCount: 99 }),
    );
  });

  test("a user cannot write their own deal count or title", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "users", ALICE), {
        dealCount: 31,
        title: "Campus Pro",
      }),
    );
  });

  test("a user cannot top up their own credits", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "users", ALICE), { credits: 90000 }),
    );
  });

  test("a user cannot release their own staked credits", async () => {
    // Otherwise losing a bid costs nothing: unlock the stake, walk away.
    await seed((db) =>
      updateDoc(doc(db, "users", ALICE), { credits: 100, creditsLocked: 40 }),
    );
    await assertFails(
      updateDoc(doc(as(ALICE), "users", ALICE), { creditsLocked: 0 }),
    );
  });

  test("a user cannot promote themselves", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "users", ALICE), { role: "moderator" }),
    );
  });

  test("another member cannot bump your rating either", async () => {
    // The old interim rule allowed exactly this, bounded. It is gone.
    await assertFails(
      updateDoc(doc(as(BOB), "users", ALICE), { rating: 5, ratingCount: 1 }),
    );
  });

  test("a user cannot lift their own suspension", async () => {
    await seed((db) =>
      updateDoc(doc(db, "users", ALICE), { isSuspended: true }),
    );
    await assertFails(
      updateDoc(doc(as(ALICE), "users", ALICE), { isSuspended: false }),
    );
  });

  test("a moderator can suspend a member", async () => {
    await assertSucceeds(
      updateDoc(doc(asModerator(), "users", ALICE), {
        isSuspended: true,
        suspendedAt: new Date(),
      }),
    );
  });

  test("a moderator still cannot rewrite reputation", async () => {
    await assertFails(
      updateDoc(doc(asModerator(), "users", ALICE), { rating: 5 }),
    );
  });

  test("a moderator cannot hand out credits either", async () => {
    await assertFails(
      updateDoc(doc(asModerator(), "users", ALICE), { credits: 2000 }),
    );
  });

  test("profiles cannot be deleted", async () => {
    await assertFails(deleteDoc(doc(as(ALICE), "users", ALICE)));
  });

  test("favourites are private to their owner", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "users", ALICE, "favorites", "l1"), {
        listingId: "l1",
        favoritedAt: new Date(),
      }),
    );
    await assertFails(
      setDoc(doc(as(BOB), "users", ALICE, "favorites", "l1"), {
        listingId: "l1",
      }),
    );
    await assertFails(
      getDoc(doc(as(BOB), "users", ALICE, "favorites", "l1")),
    );
  });
});

// ───────────────────────────────────────────────────────────── listings

describe("listings", () => {
  beforeEach(async () => {
    await seed((db) =>
      setDoc(doc(db, "listings", "listing-1"), validListing(ALICE)),
    );
  });

  test("any signed-in member can read the marketplace", async () => {
    await assertSucceeds(getDoc(doc(as(BOB), "listings", "listing-1")));
  });

  test("a signed-out visitor cannot", async () => {
    await assertFails(getDoc(doc(asAnon(), "listings", "listing-1")));
  });

  test("a member can post their own listing", async () => {
    await assertSucceeds(
      addDoc(collection(as(ALICE), "listings"), validListing(ALICE)),
    );
  });

  test("cannot post a listing in somebody else's name", async () => {
    await assertFails(
      addDoc(collection(as(BOB), "listings"), validListing(ALICE)),
    );
  });

  test("cannot post a listing that starts as sold", async () => {
    await assertFails(
      addDoc(
        collection(as(ALICE), "listings"),
        validListing(ALICE, { status: "sold" }),
      ),
    );
  });

  test("price bounds match the ones the sell form enforces", async () => {
    await assertFails(
      addDoc(
        collection(as(ALICE), "listings"),
        validListing(ALICE, { price: -1 }),
      ),
    );
    await assertFails(
      addDoc(
        collection(as(ALICE), "listings"),
        validListing(ALICE, { price: 100000 }),
      ),
    );
    await assertSucceeds(
      addDoc(
        collection(as(ALICE), "listings"),
        validListing(ALICE, { price: 99999 }),
      ),
    );
  });

  test("a title has to fit", async () => {
    await assertFails(
      addDoc(
        collection(as(ALICE), "listings"),
        validListing(ALICE, { title: "" }),
      ),
    );
    await assertFails(
      addDoc(
        collection(as(ALICE), "listings"),
        validListing(ALICE, { title: "x".repeat(121) }),
      ),
    );
  });

  test("a suspended member cannot post", async () => {
    await seed((db) =>
      updateDoc(doc(db, "users", ALICE), { isSuspended: true }),
    );
    await assertFails(
      addDoc(collection(as(ALICE), "listings"), validListing(ALICE)),
    );
  });

  test("the owner can edit and reserve their listing", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ALICE), "listings", "listing-1"), {
        price: 20,
        status: "reserved",
      }),
    );
  });

  // Step 7 moved 'sold' to onDealCompleted.
  test("the owner cannot mark their own listing sold", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "listings", "listing-1"), { status: "sold" }),
    );
  });

  test("a stranger cannot edit a listing", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "listings", "listing-1"), { price: 1 }),
    );
  });

  test("a listing cannot be handed to another owner", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "listings", "listing-1"), { userId: BOB }),
    );
  });

  test("a moderator can hide a listing but not rewrite it", async () => {
    await assertSucceeds(
      updateDoc(doc(asModerator(), "listings", "listing-1"), {
        status: "hidden",
      }),
    );
    await assertFails(
      updateDoc(doc(asModerator(), "listings", "listing-1"), {
        title: "Edited by a moderator",
      }),
    );
  });

  test("owners and moderators can delete; strangers cannot", async () => {
    await assertFails(deleteDoc(doc(as(BOB), "listings", "listing-1")));
    await assertSucceeds(deleteDoc(doc(as(ALICE), "listings", "listing-1")));
  });
});

// ──────────────────────────────────────────────────────────────── chats

describe("chats and messages", () => {
  const chatId = chatIdFor(ALICE, BOB);

  test("a member can open a chat at the derived id", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "chats", chatId), validChat(ALICE, BOB)),
    );
  });

  test("a chat cannot be seeded at an arbitrary id", async () => {
    // The id has to be the sorted participant pair, so nobody can plant a
    // conversation somewhere the two members would never look.
    await assertFails(
      setDoc(doc(as(ALICE), "chats", "some-other-id"), validChat(ALICE, BOB)),
    );
  });

  test("cannot open a chat you are not in", async () => {
    await assertFails(
      setDoc(
        doc(as("carol"), "chats", chatId),
        validChat(ALICE, BOB),
      ),
    );
  });

  describe("with an existing chat", () => {
    beforeEach(async () => {
      await seed(async (db) => {
        await setDoc(doc(db, "chats", chatId), validChat(ALICE, BOB));
        await setDoc(
          doc(db, "chats", chatId, "messages", "m1"),
          validDealMessage(ALICE, BOB),
        );
      });
    });

    test("participants can read it; outsiders cannot", async () => {
      await assertSucceeds(getDoc(doc(as(ALICE), "chats", chatId)));
      await assertFails(getDoc(doc(as("carol"), "chats", chatId)));
    });

    test("outsiders cannot read the messages", async () => {
      await assertFails(
        getDoc(doc(as("carol"), "chats", chatId, "messages", "m1")),
      );
    });

    test("a participant can send a message as themselves", async () => {
      await assertSucceeds(
        addDoc(collection(as(ALICE), "chats", chatId, "messages"), {
          senderId: ALICE,
          receiverId: BOB,
          text: "Still available?",
          timestamp: new Date(),
        }),
      );
    });

    test("cannot send a message as somebody else", async () => {
      await assertFails(
        addDoc(collection(as(ALICE), "chats", chatId, "messages"), {
          senderId: BOB,
          receiverId: ALICE,
          text: "Impersonation",
          timestamp: new Date(),
        }),
      );
    });

    test("cannot send an empty message", async () => {
      await assertFails(
        addDoc(collection(as(ALICE), "chats", chatId, "messages"), {
          senderId: ALICE,
          receiverId: BOB,
          text: "",
          timestamp: new Date(),
        }),
      );
    });

    test("a participant can update the chat metadata", async () => {
      await assertSucceeds(
        updateDoc(doc(as(ALICE), "chats", chatId), {
          lastMessage: "Still available?",
          lastTimestamp: new Date(),
          lastSenderId: ALICE,
          [`unreadCount.${BOB}`]: 1,
        }),
      );
    });

    test("cannot rewrite who is in a chat", async () => {
      await assertFails(
        updateDoc(doc(as(ALICE), "chats", chatId), {
          participants: [ALICE, "carol"],
        }),
      );
    });

    // The deal message was sent by Alice (buyer) to Bob (seller).
    test("the seller can advance the deal", async () => {
      await assertSucceeds(
        updateDoc(doc(as(BOB), "chats", chatId, "messages", "m1"), {
          "dealData.status": "accepted",
        }),
      );
    });

    test("the buyer cannot accept their own deal", async () => {
      await assertFails(
        updateDoc(doc(as(ALICE), "chats", chatId, "messages", "m1"), {
          "dealData.status": "accepted",
        }),
      );
    });

    test("the buyer cannot mark the deal complete", async () => {
      // Completion drives reputation, so it belongs to the seller alone.
      await assertFails(
        updateDoc(doc(as(ALICE), "chats", chatId, "messages", "m1"), {
          "dealData.status": "completed",
        }),
      );
    });

    test("message text is immutable", async () => {
      await assertFails(
        updateDoc(doc(as(BOB), "chats", chatId, "messages", "m1"), {
          text: "Rewritten after the fact",
        }),
      );
    });

    test("the deal price cannot be changed", async () => {
      await assertFails(
        updateDoc(doc(as(BOB), "chats", chatId, "messages", "m1"), {
          "dealData.price": 1,
        }),
      );
    });

    test("messages cannot be deleted", async () => {
      await assertFails(
        deleteDoc(doc(as(BOB), "chats", chatId, "messages", "m1")),
      );
    });
  });
});

// ────────────────────────────────────────────────────────────── reviews

describe("reviews", () => {
  const chatId = chatIdFor(ALICE, BOB);
  const id = reviewId(chatId, ALICE, BOB);

  test("a member can review their counterpart once", async () => {
    await assertSucceeds(
      setDoc(doc(as(ALICE), "reviews", id), validReview(ALICE, BOB, chatId)),
    );
  });

  test("the id has to be the derived one", async () => {
    // This is what makes "one review per deal" enforceable: a second review
    // collides with the same id, and updates are denied outright.
    await assertFails(
      setDoc(
        doc(as(ALICE), "reviews", "review_anything"),
        validReview(ALICE, BOB, chatId),
      ),
    );
  });

  test("cannot review on somebody else's behalf", async () => {
    await assertFails(
      setDoc(
        doc(as(BOB), "reviews", id),
        validReview(ALICE, BOB, chatId),
      ),
    );
  });

  test("cannot review yourself", async () => {
    const selfId = reviewId(chatId, ALICE, ALICE);
    await assertFails(
      setDoc(doc(as(ALICE), "reviews", selfId), validReview(ALICE, ALICE, chatId)),
    );
  });

  test("ratings stay within one to five", async () => {
    await assertFails(
      setDoc(
        doc(as(ALICE), "reviews", id),
        validReview(ALICE, BOB, chatId, { rating: 6 }),
      ),
    );
    await assertFails(
      setDoc(
        doc(as(ALICE), "reviews", id),
        validReview(ALICE, BOB, chatId, { rating: 0 }),
      ),
    );
  });

  test("a review cannot be edited or deleted once written", async () => {
    await seed((db) =>
      setDoc(doc(db, "reviews", id), validReview(ALICE, BOB, chatId)),
    );
    await assertFails(
      updateDoc(doc(as(ALICE), "reviews", id), { rating: 1 }),
    );
    await assertFails(deleteDoc(doc(as(ALICE), "reviews", id)));
  });
});

// ────────────────────────────────────────────────────────────── reports

describe("reports", () => {
  test("a member can file a report", async () => {
    await assertSucceeds(
      addDoc(collection(as(ALICE), "reports"), validReport(ALICE)),
    );
  });

  test("cannot file a report in somebody else's name", async () => {
    await assertFails(
      addDoc(collection(as(ALICE), "reports"), validReport(BOB)),
    );
  });

  test("cannot file a report that arrives pre-resolved", async () => {
    await assertFails(
      addDoc(
        collection(as(ALICE), "reports"),
        validReport(ALICE, { status: "dismissed" }),
      ),
    );
  });

  test("only a moderator can list the queue", async () => {
    const pending = (db) =>
      getDocs(query(collection(db, "reports"), where("status", "==", "pending")));

    await assertSucceeds(pending(asModerator()));
    await assertFails(pending(as(ALICE)));
  });

  test("a reporter can read their own report back", async () => {
    await seed((db) => setDoc(doc(db, "reports", "r1"), validReport(ALICE)));

    await assertSucceeds(getDoc(doc(as(ALICE), "reports", "r1")));
    await assertFails(getDoc(doc(as(BOB), "reports", "r1")));
  });

  test("only a moderator can resolve a report", async () => {
    await seed((db) => setDoc(doc(db, "reports", "r1"), validReport(ALICE)));

    await assertFails(
      updateDoc(doc(as(ALICE), "reports", "r1"), { status: "dismissed" }),
    );
    await assertSucceeds(
      updateDoc(doc(asModerator(), "reports", "r1"), {
        status: "reviewed",
        actionTaken: "Hide Listing",
        resolvedAt: new Date(),
        moderatorId: MOD,
      }),
    );
  });
});

describe("listings going up for auction", () => {
  test("a listing can be posted at a fixed price", async () => {
    await assertSucceeds(
      setDoc(
        doc(as(ALICE), "listings", "l-fixed"),
        validListing(ALICE, { saleMode: "fixed" }),
      ),
    );
  });

  test("but nobody can post one straight into the room", async () => {
    // Opening a floor is a callable: it has to check the listing is yours,
    // that it isn't already up, and set a closing time you don't control.
    await assertFails(
      setDoc(
        doc(as(ALICE), "listings", "l-auction"),
        validListing(ALICE, { saleMode: "auction" }),
      ),
    );
  });

  test("nor point a listing at an auction", async () => {
    // A client that could set this could point its listing at somebody
    // else's floor.
    await assertFails(
      setDoc(
        doc(as(ALICE), "listings", "l-linked"),
        validListing(ALICE, { auctionId: "auction-1" }),
      ),
    );
  });

  test("a seller cannot repoint a listing at another auction", async () => {
    await seed((db) =>
      setDoc(
        doc(db, "listings", "l-live"),
        validListing(ALICE, { saleMode: "auction", auctionId: "auction-1" }),
      ),
    );

    await assertFails(
      updateDoc(doc(as(ALICE), "listings", "l-live"), { auctionId: "auction-2" }),
    );
  });

  test("a live floor freezes the listing's price", async () => {
    // Bidders committed credits against this price.
    await seed((db) =>
      setDoc(
        doc(db, "listings", "l-frozen"),
        validListing(ALICE, { saleMode: "auction", auctionId: "auction-1" }),
      ),
    );

    await assertFails(
      updateDoc(doc(as(ALICE), "listings", "l-frozen"), { price: 1 }),
    );
  });

  test("and its title and photos", async () => {
    await seed((db) =>
      setDoc(
        doc(db, "listings", "l-frozen2"),
        validListing(ALICE, { saleMode: "auction", auctionId: "auction-1" }),
      ),
    );

    await assertFails(
      updateDoc(doc(as(ALICE), "listings", "l-frozen2"), {
        title: "Something else entirely",
      }),
    );
  });

  test("and stops the seller deleting it out from under the bidders", async () => {
    await seed((db) =>
      setDoc(
        doc(db, "listings", "l-frozen3"),
        validListing(ALICE, { saleMode: "auction", auctionId: "auction-1" }),
      ),
    );

    await assertFails(deleteDoc(doc(as(ALICE), "listings", "l-frozen3")));
  });

  test("a moderator can still take one down", async () => {
    // A listing that needs removing needs removing.
    await seed((db) =>
      setDoc(
        doc(db, "listings", "l-frozen4"),
        validListing(ALICE, { saleMode: "auction", auctionId: "auction-1" }),
      ),
    );

    await assertSucceeds(deleteDoc(doc(asModerator(), "listings", "l-frozen4")));
  });

  test("a fixed-price listing stays fully editable", async () => {
    await seed((db) =>
      setDoc(doc(db, "listings", "l-free"), validListing(ALICE)),
    );

    await assertSucceeds(
      updateDoc(doc(as(ALICE), "listings", "l-free"), {
        title: "New title",
        price: 30,
      }),
    );
  });

  test("nor take it back off auction", async () => {
    await seed((db) =>
      setDoc(
        doc(db, "listings", "l-live2"),
        validListing(ALICE, { saleMode: "auction", auctionId: "auction-1" }),
      ),
    );

    await assertFails(
      updateDoc(doc(as(ALICE), "listings", "l-live2"), { saleMode: "fixed" }),
    );
  });
});

// ─────────────────────────────────────────────────────────── auctions

describe("auctions", () => {
  const AUCTION = "auction-1";

  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, "auctions", AUCTION), validAuction(ALICE));
      await setDoc(
        doc(db, "auctions", AUCTION, "private", "config"),
        { reservePrice: 400 },
      );
      await setDoc(
        doc(db, "auctions", AUCTION, "bids", "bid-1"),
        validBid(BOB, 55),
      );
    });
  });

  test("any signed-in member can watch an auction", async () => {
    await assertSucceeds(getDoc(doc(as(BOB), "auctions", AUCTION)));
  });

  test("a signed-out visitor cannot", async () => {
    await assertFails(getDoc(doc(asAnon(), "auctions", AUCTION)));
  });

  test("bid history is public to signed-in members", async () => {
    // Seeing that you were outbid, by how much and when, is most of what
    // makes an auction legible.
    await assertSucceeds(getDocs(collection(as(BOB), "auctions", AUCTION, "bids")));
  });

  // The heart of it: an auction is the one place where everybody involved
  // wants to win, so the client writes none of it.
  test("nobody can place a bid by writing one", async () => {
    await assertFails(
      setDoc(doc(as(BOB), "auctions", AUCTION, "bids", "bid-2"), validBid(BOB, 200)),
    );
  });

  test("nobody can rewrite an existing bid", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "auctions", AUCTION, "bids", "bid-1"), {
        amount: 5000,
      }),
    );
  });

  test("nobody can make themselves the high bidder", async () => {
    await assertFails(
      updateDoc(doc(as(BOB), "auctions", AUCTION), {
        currentBid: 999,
        currentBidderId: BOB,
      }),
    );
  });

  test("the seller cannot close their own auction early", async () => {
    // Closing is the scheduled function's job. A seller who could end it
    // whenever they liked would end it the moment the price suited them.
    await assertFails(
      updateDoc(doc(as(ALICE), "auctions", AUCTION), { status: "ended_sold" }),
    );
  });

  test("the seller cannot move the closing time", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "auctions", AUCTION), {
        endsAt: new Date(Date.now() + 999999),
      }),
    );
  });

  test("nobody can create an auction from the app", async () => {
    await assertFails(
      setDoc(doc(as(ALICE), "auctions", "auction-2"), validAuction(ALICE)),
    );
  });

  test("nobody can delete an auction", async () => {
    await assertFails(deleteDoc(doc(as(ALICE), "auctions", AUCTION)));
  });

  // The reserve is the reason the private subcollection exists: rules can
  // deny a document but cannot hide a field, so a reserve stored on the
  // auction itself would be readable by every bidder.
  test("a bidder cannot read the reserve price", async () => {
    await assertFails(
      getDoc(doc(as(BOB), "auctions", AUCTION, "private", "config")),
    );
  });

  test("the seller can read their own reserve price", async () => {
    await assertSucceeds(
      getDoc(doc(as(ALICE), "auctions", AUCTION, "private", "config")),
    );
  });

  test("even the seller cannot change it once bidding has started", async () => {
    await assertFails(
      updateDoc(doc(as(ALICE), "auctions", AUCTION, "private", "config"), {
        reservePrice: 1,
      }),
    );
  });

  test("a moderator has no special access to an auction either", async () => {
    // Nothing in moderation needs to touch a live floor, and the closer is
    // the only thing that should be deciding outcomes.
    await assertFails(
      updateDoc(doc(asModerator(), "auctions", AUCTION), { status: "ended_unsold" }),
    );
  });
});

// ──────────────────────────────────────────────────── unmatched paths

describe("collections the app does not use", () => {
  test("are denied by the catch-all", async () => {
    await assertFails(
      setDoc(doc(as(ALICE), "arbitrary", "doc"), { anything: true }),
    );
  });
});
