import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { deleteObject, getBytes, ref, uploadBytes } from "firebase/storage";
import { afterAll, beforeAll, beforeEach, describe, test } from "vitest";

import { createTestEnv } from "./helpers.js";

const ALICE = "alice";
const BOB = "bob";
const LISTING = "listing-1";

let testEnv;

const as = (uid) => testEnv.authenticatedContext(uid).storage();
const asAnon = () => testEnv.unauthenticatedContext().storage();

/** A tiny JPEG payload — content is irrelevant, the metadata is what's checked. */
const jpeg = () => new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
const jpegMeta = { contentType: "image/jpeg" };

/** Path shape the app writes to: listings/{ownerId}/{listingId}/{index}.jpg */
const photoPath = (ownerId, index = 0) =>
  `listings/${ownerId}/${LISTING}/${index}.jpg`;

beforeAll(async () => {
  testEnv = await createTestEnv();
});

afterAll(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

describe("listing photos", () => {
  test("an owner can upload to their own listing folder", async () => {
    await assertSucceeds(
      uploadBytes(ref(as(ALICE), photoPath(ALICE)), jpeg(), jpegMeta),
    );
  });

  // Storage rules can't read Firestore, so ownership lives in the path. This
  // is the test that proves that design actually holds.
  test("nobody can upload into somebody else's folder", async () => {
    await assertFails(
      uploadBytes(ref(as(BOB), photoPath(ALICE)), jpeg(), jpegMeta),
    );
  });

  test("a signed-out visitor cannot upload", async () => {
    await assertFails(
      uploadBytes(ref(asAnon(), photoPath(ALICE)), jpeg(), jpegMeta),
    );
  });

  test("only images are accepted", async () => {
    await assertFails(
      uploadBytes(ref(as(ALICE), photoPath(ALICE)), jpeg(), {
        contentType: "application/pdf",
      }),
    );
  });

  test("an upload over 5 MB is rejected", async () => {
    const tooBig = new Uint8Array(5 * 1024 * 1024 + 1);
    await assertFails(
      uploadBytes(ref(as(ALICE), photoPath(ALICE)), tooBig, jpegMeta),
    );
  });

  test("any signed-in member can view listing photos", async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      uploadBytes(ref(ctx.storage(), photoPath(ALICE)), jpeg(), jpegMeta),
    );

    await assertSucceeds(getBytes(ref(as(BOB), photoPath(ALICE))));
    await assertFails(getBytes(ref(asAnon(), photoPath(ALICE))));
  });

  test("an owner can delete their own photo", async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      uploadBytes(ref(ctx.storage(), photoPath(ALICE)), jpeg(), jpegMeta),
    );

    await assertFails(deleteObject(ref(as(BOB), photoPath(ALICE))));
    await assertSucceeds(deleteObject(ref(as(ALICE), photoPath(ALICE))));
  });
});

describe("paths outside listings/", () => {
  test("are denied by the catch-all", async () => {
    await assertFails(
      uploadBytes(ref(as(ALICE), `avatars/${ALICE}.jpg`), jpeg(), jpegMeta),
    );
    await assertFails(
      uploadBytes(ref(as(ALICE), "anything.jpg"), jpeg(), jpegMeta),
    );
  });

  test("a folder one level shallow is not a listing path", async () => {
    // The rule matches listings/{userId}/{listingId}/{fileName} exactly.
    await assertFails(
      uploadBytes(ref(as(ALICE), `listings/${ALICE}/loose.jpg`), jpeg(), jpegMeta),
    );
  });
});
