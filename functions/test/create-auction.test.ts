import { beforeEach, describe, expect, test } from "vitest";

import { createAuction, maxStartPrice } from "../src/auctions";
import { clearFirestore, db, readAuction } from "./helpers";

const AMINA = "amina";
const BEN = "ben";

async function seedListing(id: string, overrides: Record<string, unknown> = {}) {
  await db.collection("listings").doc(id).set({
    title: "Signed university rugby ball",
    description: "Signed by the whole first team.",
    price: 10,
    category: "other",
    condition: "good",
    university: "Oxford",
    userId: AMINA,
    sellerName: "Amina Khan",
    imageUrls: ["https://example.test/ball.jpg"],
    status: "active",
    createdAt: new Date(),
    ...overrides,
  });
}

async function readListing(id: string) {
  return (await db.collection("listings").doc(id).get()).data() ?? {};
}

async function reserveOf(auctionId: string) {
  const snap = await db
    .collection("auctions")
    .doc(auctionId)
    .collection("private")
    .doc("config")
    .get();
  return snap.data()?.reservePrice;
}

async function refusal(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
    return "it succeeded";
  } catch (error) {
    return (error as { code?: string }).code ?? "";
  }
}

beforeEach(async () => {
  await clearFirestore();
  await seedListing("l1");
});

describe("opening a floor", () => {
  test("creates a live auction on the listing", async () => {
    const { auctionId } = await createAuction(AMINA, "l1", 12, 72);
    const auction = await readAuction(auctionId);

    expect(auction.status).toBe("live");
    expect(auction.listingId).toBe("l1");
    expect(auction.startPrice).toBe(12);
    expect(auction.bidCount).toBe(0);
    expect(auction.currentBid).toBeNull();
  });

  test("copies the title and cover photo across", async () => {
    // The room reads one document per row rather than two.
    const { auctionId } = await createAuction(AMINA, "l1", 12, 72);
    const auction = await readAuction(auctionId);

    expect(auction.listingTitle).toBe("Signed university rugby ball");
    expect(auction.listingImage).toBe("https://example.test/ball.jpg");
    expect(auction.sellerName).toBe("Amina Khan");
  });

  test("closes when the chosen duration is up", async () => {
    const now = new Date("2026-09-04T12:00:00Z");
    const { auctionId, endsAt } = await createAuction(AMINA, "l1", 12, 24, null, now);

    expect(endsAt).toBe(now.getTime() + 24 * 3_600_000);
    expect((await readAuction(auctionId)).endsAt.toMillis()).toBe(endsAt);
  });

  test("points the listing back at it", async () => {
    const { auctionId } = await createAuction(AMINA, "l1", 12, 72);
    const listing = await readListing("l1");

    expect(listing.saleMode).toBe("auction");
    expect(listing.auctionId).toBe(auctionId);
    // The listing's price becomes the opening price, so the feed and the room
    // never disagree about what it currently costs.
    expect(listing.price).toBe(12);
  });
});

describe("the reserve", () => {
  test("is kept where only the seller can read it", async () => {
    // A rule can deny a document but cannot hide a field.
    const { auctionId } = await createAuction(AMINA, "l1", 12, 72, 120);

    expect(await reserveOf(auctionId)).toBe(120);

    const auction = await readAuction(auctionId);
    expect(auction.hasReserve).toBe(true);
    expect(auction.reservePrice).toBeUndefined();
  });

  test("an auction without one says so", async () => {
    const { auctionId } = await createAuction(AMINA, "l1", 12, 72);

    expect((await readAuction(auctionId)).hasReserve).toBe(false);
    expect(await reserveOf(auctionId)).toBeUndefined();
  });

  test("cannot sit below the opening price", async () => {
    // It would never stop anything.
    expect(await refusal(createAuction(AMINA, "l1", 50, 72, 20))).toBe(
      "invalid-argument",
    );
  });

  test("cannot be higher than any bid could reach", async () => {
    expect(await refusal(createAuction(AMINA, "l1", 12, 72, 9000))).toBe(
      "invalid-argument",
    );
  });
});

describe("who may open one", () => {
  test("not somebody else's listing", async () => {
    expect(await refusal(createAuction(BEN, "l1", 12, 72))).toBe(
      "permission-denied",
    );
  });

  test("not a listing that does not exist", async () => {
    expect(await refusal(createAuction(AMINA, "nope", 12, 72))).toBe("not-found");
  });

  test("not a listing already sold", async () => {
    await seedListing("l2", { status: "sold" });

    expect(await refusal(createAuction(AMINA, "l2", 12, 72))).toBe(
      "failed-precondition",
    );
  });

  test("not twice on the same listing", async () => {
    // Two live floors on one item means two sets of bidders with a claim on it.
    await createAuction(AMINA, "l1", 12, 72);

    expect(await refusal(createAuction(AMINA, "l1", 20, 72))).toBe(
      "failed-precondition",
    );
  });

  test("a refused second attempt leaves the first alone", async () => {
    const { auctionId } = await createAuction(AMINA, "l1", 12, 72);
    await refusal(createAuction(AMINA, "l1", 20, 72));

    expect((await readListing("l1")).auctionId).toBe(auctionId);
    expect((await db.collection("auctions").get()).size).toBe(1);
  });
});

describe("the opening price", () => {
  test("cannot be below the floor", async () => {
    expect(await refusal(createAuction(AMINA, "l1", 0, 72))).toBe(
      "invalid-argument",
    );
  });

  test("cannot be above what anybody could bid", async () => {
    // A floor opened above the maximum possible bid is one nobody can bid on.
    expect(await refusal(createAuction(AMINA, "l1", maxStartPrice + 1, 72))).toBe(
      "invalid-argument",
    );
  });

  test("cannot carry pennies", async () => {
    expect(await refusal(createAuction(AMINA, "l1", 12.5, 72))).toBe(
      "invalid-argument",
    );
  });
});

describe("the duration", () => {
  test("has to be one of the offered ones", async () => {
    // Otherwise a seller could open a floor that runs for a year.
    expect(await refusal(createAuction(AMINA, "l1", 12, 8760))).toBe(
      "invalid-argument",
    );
    expect(await refusal(createAuction(AMINA, "l1", 12, 1))).toBe(
      "invalid-argument",
    );
  });

  test("all three offered ones work", async () => {
    await seedListing("l2");
    await seedListing("l3");

    for (const [listing, hours] of [
      ["l1", 24],
      ["l2", 72],
      ["l3", 168],
    ] as const) {
      const { auctionId } = await createAuction(AMINA, listing, 12, hours);
      expect((await readAuction(auctionId)).status).toBe("live");
    }
  });
});
