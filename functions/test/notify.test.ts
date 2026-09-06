import { beforeEach, describe, expect, test } from "vitest";

import { notify, registerDevice } from "../src/notify";
import { clearFirestore, db, seedUser } from "./helpers";

const BEN = "ben";

async function devicesOf(uid: string) {
  const snap = await db.collection("users").doc(uid).collection("devices").get();
  return snap.docs.map((doc) => doc.id);
}

beforeEach(async () => {
  await clearFirestore();
  await seedUser(BEN);
});

describe("registering a device", () => {
  test("stores the token as the document id", async () => {
    // Keyed by the token so re-registering the same device overwrites rather
    // than accumulating a row per launch.
    await registerDevice(BEN, "token-1", "android");
    await registerDevice(BEN, "token-1", "android");

    expect(await devicesOf(BEN)).toEqual(["token-1"]);
  });

  test("a second device is a second row", async () => {
    await registerDevice(BEN, "token-1", "android");
    await registerDevice(BEN, "token-2", "ios");

    expect((await devicesOf(BEN)).sort()).toEqual(["token-1", "token-2"]);
  });
});

describe("sending to somebody with no devices", () => {
  test("does nothing, and does not reach for FCM", async () => {
    // Load-bearing: without this guard every test in this suite would try to
    // contact the real messaging service.
    const sent = await notify(BEN, "Title", "Body", {
      kind: "auction",
      id: "a1",
    });

    expect(sent).toBe(0);
  });

  test("nor for somebody who does not exist", async () => {
    const sent = await notify("ghost", "Title", "Body", {
      kind: "auction",
      id: "a1",
    });

    expect(sent).toBe(0);
  });
});
