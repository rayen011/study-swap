/**
 * Gives credit balances to accounts that predate the credits feature.
 *
 * `credits` and `creditsLocked` are written by Cloud Functions from the moment
 * they exist, and by `firestore.rules` at signup. Neither reaches backwards:
 * every profile created before this feature has no balance at all, reads as
 * zero in the app, and would stay at zero until its owner happens to complete
 * another deal. That is a real member with a real trading history looking at
 * an empty number, so their history is converted once, here.
 *
 * Unlike seed.mjs, this touches accounts that are not demo data, so it does
 * nothing until you pass --apply. Without it, it prints the plan and exits.
 *
 * Usage:
 *   node tools/backfill-credits.mjs           # show what would change
 *   node tools/backfill-credits.mjs --apply   # do it
 *
 * Safe to run more than once: an account that already has a balance is
 * skipped, so a rerun never overwrites what the triggers have been keeping up
 * to date since.
 */

import { readFileSync } from "node:fs";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { CREDITS, creditsFromHistory } from "./credit-rules.mjs";

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

const apply = process.argv.includes("--apply");

async function main() {
  const snap = await db.collection("users").get();

  const pending = [];
  let alreadySet = 0;

  for (const doc of snap.docs) {
    const data = doc.data();

    if (typeof data.credits === "number") {
      alreadySet++;
      continue;
    }

    pending.push({
      ref: doc.ref,
      name: data.fullName ?? doc.id,
      dealCount: data.dealCount ?? 0,
      ratingCount: data.ratingCount ?? 0,
      credits: creditsFromHistory(data),
    });
  }

  console.log(
    `\n${snap.size} profiles: ${alreadySet} already have a balance, ` +
      `${pending.length} to backfill.\n`,
  );

  if (pending.length === 0) {
    console.log("Nothing to do.\n");
    return;
  }

  for (const user of pending) {
    console.log(
      `  ${user.name.padEnd(24)} ${String(user.dealCount).padStart(3)} deals, ` +
        `${String(user.ratingCount).padStart(3)} reviews  →  ${user.credits} credits`,
    );
  }

  if (!apply) {
    console.log(
      `\nNothing written. Every past deal is credited at the buyer rate ` +
        `(${CREDITS.buyerCompletion}), since which side of a deal somebody was ` +
        `on is not recorded on their profile.\n` +
        `Run again with --apply to write these.\n`,
    );
    return;
  }

  // Firestore caps a batch at 500 writes.
  for (let i = 0; i < pending.length; i += 400) {
    const batch = db.batch();
    for (const user of pending.slice(i, i + 400)) {
      batch.update(user.ref, { credits: user.credits, creditsLocked: 0 });
    }
    await batch.commit();
  }

  console.log(`\nBackfilled ${pending.length} profiles.\n`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
