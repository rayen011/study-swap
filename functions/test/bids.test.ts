import { beforeEach, describe, expect, test } from "vitest";

import { AUCTION } from "../src/auctions";
import { placeBid } from "../src/bids";
import {
  clearFirestore,
  readAuction,
  readBids,
  readUser,
  seedAuction,
  seedUser,
} from "./helpers";

const AMINA = "amina";
const BEN = "ben";
const CHLOE = "chloe";

/** The code on a rejection, or the message when there isn't one. */
async function refusal(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
    return "it succeeded";
  } catch (error) {
    return (error as { code?: string; message: string }).code ?? "";
  }
}

/** The human message on a rejection, which the app shows as-is. */
async function refusalMessage(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
    return "it succeeded";
  } catch (error) {
    return (error as { message: string }).message;
  }
}

beforeEach(async () => {
  await clearFirestore();
  await seedUser(BEN, { credits: 200 });
  await seedUser(CHLOE, { credits: 200 });
  await seedUser(AMINA, { credits: 400 });
});

describe("a first bid", () => {
  beforeEach(() => seedAuction("a1", { sellerId: AMINA, endsInMinutes: 60 }));

  test("can meet the starting price exactly", async () => {
    const result = await placeBid(BEN, "a1", 20);

    expect(result.amount).toBe(20);
    expect((await readAuction("a1")).currentBid).toBe(20);
    expect((await readAuction("a1")).currentBidderId).toBe(BEN);
  });

  test("holds a tenth of itself", async () => {
    const result = await placeBid(BEN, "a1", 20);

    expect(result.stakeLocked).toBe(2);
    expect((await readUser(BEN)).creditsLocked).toBe(2);
    // Held, not spent: the balance itself does not move.
    expect((await readUser(BEN)).credits).toBe(200);
  });

  test("is recorded with the bidder's name on it", async () => {
    // Denormalised so bid history doesn't need a profile read per row.
    const result = await placeBid(BEN, "a1", 20);
    const bid = (await readBids("a1"))[result.bidId];

    expect(bid.bidderId).toBe(BEN);
    expect(bid.bidderName).toBe(BEN);
    expect(bid.status).toBe("active");
    expect(bid.stakeLocked).toBe(2);
  });

  test("counts", async () => {
    await placeBid(BEN, "a1", 20);

    expect((await readAuction("a1")).bidCount).toBe(1);
  });

  test("below the starting price is refused", async () => {
    expect(await refusal(placeBid(BEN, "a1", 19))).toBe("failed-precondition");
    expect((await readAuction("a1")).currentBid).toBeNull();
  });
});

describe("outbidding", () => {
  beforeEach(async () => {
    await seedAuction("a1", { sellerId: AMINA, endsInMinutes: 60 });
    await placeBid(BEN, "a1", 100);
  });

  test("the new bid leads", async () => {
    await placeBid(CHLOE, "a1", 105);

    const auction = await readAuction("a1");
    expect(auction.currentBid).toBe(105);
    expect(auction.currentBidderId).toBe(CHLOE);
    expect(auction.bidCount).toBe(2);
  });

  test("the beaten bidder gets their credits back immediately", async () => {
    // Being outbid has to be instant, or holding a bid on four auctions costs
    // more than it should and the whole ceiling stops meaning anything.
    expect((await readUser(BEN)).creditsLocked).toBe(10);

    await placeBid(CHLOE, "a1", 105);

    expect((await readUser(BEN)).creditsLocked).toBe(0);
    expect((await readUser(CHLOE)).creditsLocked).toBe(11);
  });

  test("the beaten bid is marked outbid", async () => {
    await placeBid(CHLOE, "a1", 105);

    const bids = Object.values(await readBids("a1"));
    expect(bids.filter((b) => b.status === "active")).toHaveLength(1);
    expect(bids.filter((b) => b.status === "outbid")).toHaveLength(1);
  });

  test("must clear the increment, not just the current bid", async () => {
    // £101 beats £100 and would make an auction a war of pennies.
    expect(await refusal(placeBid(CHLOE, "a1", 101))).toBe("failed-precondition");
    expect((await readAuction("a1")).currentBid).toBe(100);
  });

  test("the refusal says what would be enough", async () => {
    // A bidder told "invalid argument" has learned nothing about what to do.
    expect(await refusalMessage(placeBid(CHLOE, "a1", 101))).toContain("£105");
  });

  test("nobody can outbid themselves", async () => {
    // It buys the same position and locks more credits doing it.
    expect(await refusal(placeBid(BEN, "a1", 200))).toBe("failed-precondition");
    expect((await readUser(BEN)).creditsLocked).toBe(10);
  });

  test("a bidder who returns after being outbid holds only the new stake", async () => {
    await placeBid(CHLOE, "a1", 105);
    await placeBid(BEN, "a1", 120);

    expect((await readUser(BEN)).creditsLocked).toBe(12);
    expect((await readUser(CHLOE)).creditsLocked).toBe(0);
  });
});

describe("who may bid", () => {
  beforeEach(() => seedAuction("a1", { sellerId: AMINA, endsInMinutes: 60 }));

  test("not the seller", async () => {
    // Shill bidding is the oldest way to rig an auction and the cheapest to
    // make impossible.
    expect(await refusal(placeBid(AMINA, "a1", 50))).toBe("permission-denied");
  });

  test("not a suspended account", async () => {
    await seedUser(BEN, { credits: 200 });
    const { db } = await import("./helpers");
    await db.collection("users").doc(BEN).update({ isSuspended: true });

    expect(await refusal(placeBid(BEN, "a1", 50))).toBe("permission-denied");
  });

  test("not somebody with no profile", async () => {
    expect(await refusal(placeBid("ghost", "a1", 50))).toBe("not-found");
  });
});

describe("the ceiling", () => {
  beforeEach(() => seedAuction("a1", { sellerId: AMINA, endsInMinutes: 60 }));

  test("a bid within it is fine", async () => {
    // 200 free credits × 10 = £2,000, which the hard cap also happens to be.
    await seedUser(BEN, { credits: 200 });

    expect((await placeBid(BEN, "a1", 2000)).amount).toBe(2000);
  });

  test("a bid past it is refused", async () => {
    await seedUser(BEN, { credits: 50 });

    expect(await refusal(placeBid(BEN, "a1", 501))).toBe("failed-precondition");
  });

  test("the refusal says what the ceiling is and how to raise it", async () => {
    await seedUser(BEN, { credits: 50 });

    const message = await refusalMessage(placeBid(BEN, "a1", 501));
    expect(message).toContain("£500");
    expect(message).toContain("Complete more deals");
  });

  test("credits already staked elsewhere do not count twice", async () => {
    // This is what stops one member holding open bids on everything.
    await seedUser(BEN, { credits: 200, creditsLocked: 180 });

    expect(await refusal(placeBid(BEN, "a1", 300))).toBe("failed-precondition");
    expect((await placeBid(BEN, "a1", 200)).amount).toBe(200);
  });

  test("nobody can bid ninety thousand pounds", async () => {
    // The whole reason credits exist.
    await seedUser(BEN, { credits: 100000 });

    expect(await refusal(placeBid(BEN, "a1", 90000))).toBe("failed-precondition");
  });
});

describe("the clock", () => {
  test("a closed auction takes no more bids", async () => {
    await seedAuction("a1", { sellerId: AMINA, status: "ended_unsold" });

    expect(await refusal(placeBid(BEN, "a1", 50))).toBe("failed-precondition");
  });

  test("a live auction whose time has passed takes none either", async () => {
    // The closer runs once a minute, so there is always a window where the
    // document still says live and the clock has already run out.
    await seedAuction("a1", { sellerId: AMINA, endsInMinutes: -1 });

    expect(await refusal(placeBid(BEN, "a1", 50))).toBe("failed-precondition");
    expect((await readAuction("a1")).status).toBe("live");
  });

  test("a bid with time to spare leaves the ending alone", async () => {
    await seedAuction("a1", { sellerId: AMINA, endsInMinutes: 60 });
    const before = (await readAuction("a1")).endsAt.toMillis();

    const result = await placeBid(BEN, "a1", 50);

    expect(result.extended).toBe(false);
    expect((await readAuction("a1")).endsAt.toMillis()).toBe(before);
  });

  test("a late bid pushes the ending out", async () => {
    // Otherwise the winner is whoever has the best reflexes at closing time,
    // and everybody else learns not to bother bidding early.
    await seedAuction("a1", { sellerId: AMINA, endsInMinutes: 1 });
    const before = (await readAuction("a1")).endsAt.toMillis();

    const result = await placeBid(BEN, "a1", 50);

    expect(result.extended).toBe(true);
    expect(result.endsAt).toBeGreaterThan(before);
    expect((await readAuction("a1")).extensionsMs).toBeGreaterThan(0);
  });

  test("an auction that has used its extension budget stops moving", async () => {
    await seedAuction("a1", { sellerId: AMINA, endsInMinutes: 1 });
    const { db } = await import("./helpers");
    await db
      .collection("auctions")
      .doc("a1")
      .update({ extensionsMs: AUCTION.maxExtensionMs });

    const before = (await readAuction("a1")).endsAt.toMillis();
    const result = await placeBid(BEN, "a1", 50);

    expect(result.extended).toBe(false);
    expect((await readAuction("a1")).endsAt.toMillis()).toBe(before);
  });
});

describe("bad input", () => {
  beforeEach(() => seedAuction("a1", { sellerId: AMINA, endsInMinutes: 60 }));

  test("pennies are refused", async () => {
    // Whole pounds throughout: a £52.55 minimum invites a £52.56 bid.
    expect(await refusal(placeBid(BEN, "a1", 52.55))).toBe("invalid-argument");
  });

  test("so are zero and negative bids", async () => {
    expect(await refusal(placeBid(BEN, "a1", 0))).toBe("invalid-argument");
    expect(await refusal(placeBid(BEN, "a1", -50))).toBe("invalid-argument");
  });

  test("an auction that does not exist", async () => {
    expect(await refusal(placeBid(BEN, "nope", 50))).toBe("not-found");
  });
});

// Deliberately contended, so Firestore retries the loser's transaction —
// which is exactly what is being tested, and is also slow. The default 5s
// budget is enough on a quiet machine and not on a busy one, and a race test
// that fails intermittently teaches people to re-run rather than to look.
describe("two bids at once", { timeout: 30_000 }, () => {
  test("only one of them can win", async () => {
    // The case that would actually bite: two people bidding the same amount
    // in the same instant must not both become the high bidder, and must not
    // both lock a stake against a position only one of them holds.
    await seedAuction("a1", { sellerId: AMINA, endsInMinutes: 60 });

    const results = await Promise.allSettled([
      placeBid(BEN, "a1", 51),
      placeBid(CHLOE, "a1", 51),
    ]);

    const won = results.filter((r) => r.status === "fulfilled");
    expect(won).toHaveLength(1);

    const auction = await readAuction("a1");
    expect(auction.bidCount).toBe(1);
    expect([BEN, CHLOE]).toContain(auction.currentBidderId);

    // The loser holds nothing.
    const locked =
      (await readUser(BEN)).creditsLocked + (await readUser(CHLOE)).creditsLocked;
    expect(locked).toBe(6);
  });

  test("a race between different amounts leaves one leader and one refund", async () => {
    await seedAuction("a1", { sellerId: AMINA, endsInMinutes: 60 });

    await Promise.allSettled([
      placeBid(BEN, "a1", 60),
      placeBid(CHLOE, "a1", 80),
    ]);

    const auction = await readAuction("a1");
    const bids = Object.values(await readBids("a1"));
    const active = bids.filter((b) => b.status === "active");

    // Whoever ended up leading, exactly one bid stands and it is theirs.
    expect(active).toHaveLength(1);
    expect(active[0].bidderId).toBe(auction.currentBidderId);
    expect(active[0].amount).toBe(auction.currentBid);

    // And nobody is holding credits for a bid that no longer stands.
    const held =
      (await readUser(BEN)).creditsLocked + (await readUser(CHLOE)).creditsLocked;
    expect(held).toBe(active[0].stakeLocked);
  });
});
