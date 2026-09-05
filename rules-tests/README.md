# Security rules tests

70 tests that run `firestore.rules` and `storage.rules` against the Firebase emulators.

These exist because rules are the only thing standing between a hostile client and the
database, and unlike Dart code they fail *silently* in the wrong direction: a rule that's
too strict shows up as a broken feature, and one that's too loose shows up as nothing at
all until someone notices.

## Running them

Needs **JDK 21+** — `firebase-tools` refuses anything older.

```bash
npm install
npm run emulate
```

`npm run emulate` starts the Firestore and Storage emulators, runs the suite against
them, and shuts them down. `npm test` alone assumes emulators are already up.

Both rules files are read from the repo root, so the tests always run against exactly
what `firebase deploy` would push.

## What's covered

| Area | Examples |
| --- | --- |
| Profiles | Can't sign up as a moderator, can't write your own rating, can't lift your own suspension, can't edit somebody else's profile |
| Listings | Owner-only edits, price and title bounds matching the sell form, `sold` reserved for the Cloud Function, moderators can hide but not rewrite |
| Chats | The document id must be the derived participant pair, outsiders can't read, nobody can send a message as somebody else |
| Deals | Only the seller advances a deal; the buyer can't accept or complete their own |
| Reviews | The deterministic id is required, ratings stay in 1–5, no self-reviews, and a written review can't be edited or deleted |
| Reports | Can't file in somebody else's name or pre-resolved; only moderators can list the queue or resolve |
| Storage | Ownership comes from the path, images only, 5 MB cap, and nothing outside `listings/` is writable |

## A note on trusting this suite

An `assertFails` test passes just as happily when the operation fails for the *wrong*
reason — a typo in a field name, a malformed document. A green run proves less than it
looks like.

So the suite was mutation-tested: two rules were deliberately loosened (letting a user
write their own `rating`, and letting either party complete a deal) and the run was
repeated. Three tests failed, including one that wasn't predicted — the buyer being able
to accept their own deal, which the second mutation also allowed. The rules were then
restored from git.

Worth repeating that exercise if you add rules. A security test suite that has never
been seen to fail hasn't been shown to work.
