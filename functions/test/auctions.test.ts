import { beforeEach, describe, expect, test } from "vitest";

import { AUCTION, extendedEnd, minimumBidFor, settleAuction } from "../src/auctions";
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

beforeEach(clearFirestore);

// ─────────────────────────────────────────────────── the bidding arithmetic

describe("the minimum bid", () => {
  test("an auction with no bids can be met at its starting price", () => {
    expect(minimumBidFor(20, null)).toBe(20);
    expect(minimumBidFor(20, undefined)).toBe(20);
  });

  test("small bids step by a pound, large ones by five percent", () => {
    expect(minimumBidFor(10, 10)).toBe(11);
    expect(minimumBidFor(10, 100)).toBe(105);
  });

  test("never asks for pennies", () => {
    expect(minimumBidFor(10, 50.1)).toBe(53);
  });
});

describe("the snipe extension", () => {
  const end = 1_000_000;

  test("leaves a bid with time to spare alone", () => {
    const now = end - AUCTION.snipeWindowMs - 1;

    expect(extendedEnd(end, 0, now)).toEqual({ endsAtMs: end, extensionsMs: 0 });
  });

  test("pushes the end out for a late bid", () => {
    // Otherwise the winner is whoever has the best reflexes at closing time.
    const now = end - 30_000;
    const result = extendedEnd(end, 0, now);

    expect(result.endsAtMs).toBe(now + AUCTION.snipeWindowMs);
    expect(result.extensionsMs).toBe(result.endsAtMs - end);
  });

  test("stops extending once the cap is spent", () => {
    // An auction sniped repeatedly has to settle rather than run all night.
    const now = end - 30_000;
    const result = extendedEnd(end, AUCTION.maxExtensionMs, now);

    expect(result).toEqual({
      endsAtMs: end,
      extensionsMs: AUCTION.maxExtensionMs,
    });
  });

  test("grants only what is left of the cap", () => {
    const spent = AUCTION.maxExtensionMs - 10_000;
    const now = end - 30_000;
    const result = extendedEnd(end, spent, now);

    expect(result.endsAtMs).toBe(end + 10_000);
    expect(result.extensionsMs).toBe(AUCTION.maxExtensionMs);
  });
});

// ─────────────────────────────────────────────────────────────── closing

describe("closing an auction with no bids", () => {
  test("ends unsold", async () => {
    await seedAuction("a1", { sellerId: AMINA });

    const result = await settleAuction("a1");

    expect(result.outcome).toBe("ended_unsold");
    expect((await readAuction("a1")).status).toBe("ended_unsold");
  });

  test("names no winner", async () => {
    await seedAuction("a1", { sellerId: AMINA });

    await settleAuction("a1");

    const auction = await readAuction("a1");
    expect(auction.winnerId).toBeNull();
    expect(auction.winningBid).toBeNull();
  });
});

describe("closing an auction that met its price", () => {
  beforeEach(async () => {
    await seedUser(BEN, { credits: 200, creditsLocked: 6 });
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 55,
      currentBidderId: BEN,
      bids: [{ bidderId: BEN, amount: 55, stake: 6 }],
    });
  });

  test("sells to the leading bidder", async () => {
    const result = await settleAuction("a1");

    expect(result.outcome).toBe("ended_sold");
    expect(result.winnerId).toBe(BEN);

    const auction = await readAuction("a1");
    expect(auction.status).toBe("ended_sold");
    expect(auction.winnerId).toBe(BEN);
    expect(auction.winningBid).toBe(55);
  });

  test("marks the winning bid won", async () => {
    await settleAuction("a1");

    expect((await readBids("a1"))["bid-0"].status).toBe("won");
  });

  test("keeps the winner's stake locked", async () => {
    // Releasing it here would leave a winner with nothing to lose by never
    // turning up, which is the whole deterrent.
    await settleAuction("a1");

    expect((await readUser(BEN)).creditsLocked).toBe(6);
  });
});

describe("the reserve", () => {
  test("a bid under it does not sell", async () => {
    await seedUser(BEN, { creditsLocked: 6 });
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 55,
      currentBidderId: BEN,
      reservePrice: 400,
      bids: [{ bidderId: BEN, amount: 55, stake: 6 }],
    });

    const result = await settleAuction("a1");

    expect(result.outcome).toBe("ended_unsold");
    expect((await readAuction("a1")).reserveMet).toBe(false);
  });

  test("gives the bidder their stake back", async () => {
    // Nobody did anything wrong: the item just didn't reach its price.
    await seedUser(BEN, { creditsLocked: 6 });
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 55,
      currentBidderId: BEN,
      reservePrice: 400,
      bids: [{ bidderId: BEN, amount: 55, stake: 6 }],
    });

    await settleAuction("a1");

    expect((await readUser(BEN)).creditsLocked).toBe(0);
    expect((await readBids("a1"))["bid-0"].status).toBe("outbid");
  });

  test("a bid that exactly meets it sells", async () => {
    await seedUser(BEN, { creditsLocked: 40 });
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 400,
      currentBidderId: BEN,
      reservePrice: 400,
      bids: [{ bidderId: BEN, amount: 400, stake: 40 }],
    });

    const result = await settleAuction("a1");

    expect(result.outcome).toBe("ended_sold");
    expect((await readAuction("a1")).reserveMet).toBe(true);
  });

  test("an auction without one sells to any bid", async () => {
    await seedUser(BEN, { creditsLocked: 3 });
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 21,
      currentBidderId: BEN,
      bids: [{ bidderId: BEN, amount: 21, stake: 3 }],
    });

    expect((await settleAuction("a1")).outcome).toBe("ended_sold");
    expect((await readAuction("a1")).reserveMet).toBe(true);
  });
});

describe("stakes still standing at close", () => {
  test("everyone but the winner gets theirs back", async () => {
    // Outbid stakes are released when the bid is beaten, so a second active
    // one at close means something went wrong earlier. The closer is the last
    // place that can put it right, so it does.
    await seedUser(BEN, { creditsLocked: 6 });
    await seedUser(CHLOE, { creditsLocked: 5 });
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 55,
      currentBidderId: BEN,
      bids: [
        { bidderId: BEN, amount: 55, stake: 6 },
        { bidderId: CHLOE, amount: 50, stake: 5 },
      ],
    });

    const result = await settleAuction("a1");

    expect(result.stakesReleased).toBe(1);
    expect((await readUser(BEN)).creditsLocked).toBe(6);
    expect((await readUser(CHLOE)).creditsLocked).toBe(0);
  });

  test("a locked total behind its stakes lands on zero, not below", async () => {
    // A member who ends up owing credits can never work the debt off, and
    // every ceiling they see afterwards would be wrong.
    await seedUser(BEN, { creditsLocked: 2 });
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 55,
      currentBidderId: CHLOE,
      bids: [{ bidderId: BEN, amount: 50, stake: 40 }],
    });

    await settleAuction("a1");

    expect((await readUser(BEN)).creditsLocked).toBe(0);
  });

  test("a bidder whose account is gone does not stop the close", async () => {
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 55,
      currentBidderId: BEN,
      bids: [{ bidderId: "deleted-account", amount: 50, stake: 5 }],
    });

    expect((await settleAuction("a1")).outcome).toBe("ended_sold");
  });
});

describe("closing twice", () => {
  test("the second pass does nothing", async () => {
    // A scheduled function is retried on failure and can overlap with itself,
    // so this is load-bearing rather than defensive.
    await seedUser(BEN, { creditsLocked: 6 });
    await seedAuction("a1", {
      sellerId: AMINA,
      currentBid: 55,
      currentBidderId: BEN,
      reservePrice: 400,
      bids: [{ bidderId: BEN, amount: 55, stake: 6 }],
    });

    await settleAuction("a1");
    const result = await settleAuction("a1");

    expect(result.outcome).toBe("not_live");
    // The stake came back once, not twice.
    expect((await readUser(BEN)).creditsLocked).toBe(0);
  });
});

describe("refusing to close", () => {
  test("an auction whose time has not come", async () => {
    await seedAuction("a1", { sellerId: AMINA, endsInMinutes: 30 });

    expect((await settleAuction("a1")).outcome).toBe("not_due");
    expect((await readAuction("a1")).status).toBe("live");
  });

  test("an auction that does not exist", async () => {
    expect((await settleAuction("nothing-here")).outcome).toBe("missing");
  });

  test("an auction somebody already settled", async () => {
    await seedAuction("a1", { sellerId: AMINA, status: "settled" });

    expect((await settleAuction("a1")).outcome).toBe("not_live");
  });
});
