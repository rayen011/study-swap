import { beforeEach, describe, expect, test } from "vitest";

import { settleAuction } from "../src/auctions";
import {
  ABANDON_AFTER_MS,
  chatIdFor,
  findAbandonedAuctions,
  forfeitAbandonedAuction,
  settleCompletedAuction,
} from "../src/handoff";
import {
  clearFirestore,
  db,
  readAuction,
  readBids,
  readUser,
  seedAuction,
  seedUser,
} from "./helpers";

const AMINA = "amina";
const BEN = "ben";
const CHLOE = "chloe";

async function readChat(a: string, b: string) {
  return (await db.collection("chats").doc(chatIdFor(a, b)).get()).data();
}

async function readDeals(a: string, b: string) {
  const snap = await db
    .collection("chats")
    .doc(chatIdFor(a, b))
    .collection("messages")
    .where("type", "==", "deal")
    .get();

  return snap.docs.map((doc) => doc.data());
}

/** A sold auction with Ben as the winner, closed [minutesAgo] minutes ago. */
async function soldToBen(id = "a1", minutesAgo = 0) {
  await seedAuction(id, {
    sellerId: AMINA,
    currentBid: 96,
    currentBidderId: BEN,
    bids: [
      { bidderId: BEN, amount: 96, stake: 10 },
      { bidderId: CHLOE, amount: 90, stake: 9, status: "outbid" },
    ],
  });

  await settleAuction(id);

  if (minutesAgo > 0) {
    await db
      .collection("auctions")
      .doc(id)
      .update({ endedAt: new Date(Date.now() - minutesAgo * 60_000) });
  }
}

beforeEach(async () => {
  await clearFirestore();
  await seedUser(AMINA, { credits: 400 });
  await seedUser(BEN, { credits: 200, creditsLocked: 10 });
  await seedUser(CHLOE, { credits: 200 });
});

describe("winning", () => {
  test("opens a chat between the winner and the seller", async () => {
    await soldToBen();

    const chat = await readChat(BEN, AMINA);
    expect(chat).toBeDefined();
    expect(chat!.participants).toEqual([AMINA, BEN].sort());
  });

  test("drops in a deal card at the winning price", async () => {
    await soldToBen();

    const [deal] = await readDeals(BEN, AMINA);
    expect(deal.dealData.price).toBe(96);
    expect(deal.dealData.buyerId).toBe(BEN);
    expect(deal.dealData.sellerId).toBe(AMINA);
  });

  test("the deal is already accepted", async () => {
    // The bid was the agreement. Asking the seller to accept a deal the
    // auction already decided would be theatre.
    await soldToBen();

    const [deal] = await readDeals(BEN, AMINA);
    expect(deal.dealData.status).toBe("accepted");
  });

  test("the deal remembers which auction it came from", async () => {
    // Settlement has to find the auction back from the deal.
    await soldToBen();

    const [deal] = await readDeals(BEN, AMINA);
    expect(deal.dealData.auctionId).toBe("a1");
  });

  test("the auction points at the chat", async () => {
    await soldToBen();

    expect((await readAuction("a1")).chatId).toBe(chatIdFor(BEN, AMINA));
  });

  test("the winner sees it as unread", async () => {
    await soldToBen();

    const chat = await readChat(BEN, AMINA);
    expect(chat!.unreadCount[BEN]).toBe(1);
    expect(chat!.unreadCount[AMINA]).toBe(0);
  });

  test("an existing conversation is used rather than replaced", async () => {
    // They may well have traded before. A second chat document at a different
    // id would be invisible to both of them.
    await db
      .collection("chats")
      .doc(chatIdFor(BEN, AMINA))
      .set({
        participants: [AMINA, BEN].sort(),
        participantNames: { [AMINA]: "Amina Khan", [BEN]: "Ben Ito" },
        unreadCount: { [AMINA]: 0, [BEN]: 3 },
        lastMessage: "See you Thursday",
        createdAt: new Date(),
      });

    await soldToBen();

    const chat = await readChat(BEN, AMINA);
    expect(chat!.participantNames[BEN]).toBe("Ben Ito");
    expect(chat!.unreadCount[BEN]).toBe(4);
  });

  test("an unsold auction opens nothing", async () => {
    await seedAuction("a2", { sellerId: AMINA, reservePrice: 400 });
    await settleAuction("a2");

    expect(await readChat(BEN, AMINA)).toBeUndefined();
    expect((await readAuction("a2")).chatId).toBeNull();
  });
});

describe("completing the handover", () => {
  test("gives the winner their stake back", async () => {
    await soldToBen();
    expect((await readUser(BEN)).creditsLocked).toBe(10);

    await settleCompletedAuction("a1", BEN);

    expect((await readUser(BEN)).creditsLocked).toBe(0);
  });

  test("marks the auction settled", async () => {
    await soldToBen();
    await settleCompletedAuction("a1", BEN);

    expect((await readAuction("a1")).status).toBe("settled");
    expect((await readBids("a1"))["bid-0"].status).toBe("settled");
  });

  test("running twice does not hand the stake back twice", async () => {
    // Firestore triggers can fire more than once for one write.
    await soldToBen();
    await seedUser(BEN, { credits: 200, creditsLocked: 25 });

    await settleCompletedAuction("a1", BEN);
    await settleCompletedAuction("a1", BEN);

    expect((await readUser(BEN)).creditsLocked).toBe(15);
  });

  test("an auction that never sold is left alone", async () => {
    await seedAuction("a2", { sellerId: AMINA });
    await settleAuction("a2");

    await settleCompletedAuction("a2", BEN);

    expect((await readAuction("a2")).status).toBe("ended_unsold");
  });
});

describe("finding abandoned wins", () => {
  test("ignores one still inside the window", async () => {
    await soldToBen("a1", 60);

    expect(await findAbandonedAuctions()).toEqual([]);
  });

  test("catches one past it", async () => {
    await soldToBen("a1", ABANDON_AFTER_MS / 60_000 + 10);

    expect(await findAbandonedAuctions()).toEqual(["a1"]);
  });

  test("ignores one already settled", async () => {
    await soldToBen("a1", ABANDON_AFTER_MS / 60_000 + 10);
    await settleCompletedAuction("a1", BEN);

    expect(await findAbandonedAuctions()).toEqual([]);
  });
});

describe("a winner who never turned up", () => {
  beforeEach(() => soldToBen("a1", ABANDON_AFTER_MS / 60_000 + 10));

  test("loses the stake for good", async () => {
    // The entire deterrent. Without it, winning costs nothing and bidding
    // high costs nothing.
    await forfeitAbandonedAuction("a1");

    const ben = await readUser(BEN);
    expect(ben.credits).toBe(190);
    expect(ben.creditsLocked).toBe(0);
  });

  test("and the seller gets it, for the auction they wasted", async () => {
    await forfeitAbandonedAuction("a1");

    expect((await readUser(AMINA)).credits).toBe(410);
  });

  test("the auction reads as abandoned", async () => {
    await forfeitAbandonedAuction("a1");

    const auction = await readAuction("a1");
    expect(auction.status).toBe("abandoned");
    expect(auction.forfeitedCredits).toBe(10);
    expect((await readBids("a1"))["bid-0"].status).toBe("forfeited");
  });

  test("the runner-up is offered it at their own bid", async () => {
    await forfeitAbandonedAuction("a1");

    const [deal] = await readDeals(CHLOE, AMINA);
    expect(deal.dealData.price).toBe(90);
    expect(deal.dealData.buyerId).toBe(CHLOE);
    expect(deal.dealData.status).toBe("accepted");
  });

  test("the runner-up is not charged a stake they never agreed to", async () => {
    // Chloe's stake came back the moment she was outbid. Re-locking credits
    // for an offer she has not accepted would take them without asking.
    await forfeitAbandonedAuction("a1");

    expect((await readUser(CHLOE)).creditsLocked).toBe(0);
  });

  test("with nobody else in the running, the stake still moves", async () => {
    await clearFirestore();
    await seedUser(AMINA, { credits: 400 });
    await seedUser(BEN, { credits: 200, creditsLocked: 10 });

    await seedAuction("solo", {
      sellerId: AMINA,
      currentBid: 96,
      currentBidderId: BEN,
      bids: [{ bidderId: BEN, amount: 96, stake: 10 }],
    });
    await settleAuction("solo");
    await db
      .collection("auctions")
      .doc("solo")
      .update({ endedAt: new Date(Date.now() - ABANDON_AFTER_MS - 60_000) });

    const result = await forfeitAbandonedAuction("solo");

    expect(result.forfeited).toBe(10);
    expect(result.runnerUpId).toBeNull();
    expect((await readUser(AMINA)).credits).toBe(410);
  });

  test("running twice does not charge them twice", async () => {
    await forfeitAbandonedAuction("a1");
    await forfeitAbandonedAuction("a1");

    expect((await readUser(BEN)).credits).toBe(190);
    expect((await readUser(AMINA)).credits).toBe(410);
  });

  test("one that completed in time is beyond forfeiting", async () => {
    await settleCompletedAuction("a1", BEN);
    const before = (await readUser(BEN)).credits;

    await forfeitAbandonedAuction("a1");

    expect((await readUser(BEN)).credits).toBe(before);
    expect((await readAuction("a1")).status).toBe("settled");
  });
});
