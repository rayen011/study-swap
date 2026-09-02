# StudySwap Cloud Functions

Server-side logic for the things a client can't be trusted with.

## Why these exist

Reputation used to be computed on the user's device. `submitRating` and
`completeDeal` ran Firestore transactions that wrote `rating`, `ratingCount`,
`dealCount` and `title` straight onto user documents — so anyone could give
themselves a 5.0 average and the top badge with a single write.

Those fields now appear in no client-writable shape in `firestore.rules`. The
Admin SDK bypasses rules, which is what lets these triggers write fields nobody
else can.

## What runs

| Function | Trigger | Owns |
| --- | --- | --- |
| `onReviewCreated` | `reviews/{id}` created | `rating`, `ratingCount` |
| `onDealCompleted` | deal message status → `completed` | both parties' `dealCount` and `title`, and marking the listing sold |
| `onListingDeleted` | `listings/{id}` deleted | removing the listing's Storage folder |
| `onSuspensionChanged` | `users/{id}.isSuspended` flips | disabling / re-enabling the Auth account |
| `setModeratorRole` | callable | granting and revoking the moderator claim |

Reputation titles by deal count live in `titleForDeals` in `src/index.ts`, and
that is now the only definition — the Dart copy and the `firestore.rules` copy
were both deleted once no client could write the field.

## Develop

```bash
npm install
npm run build         # or: npm run build:watch
npm run serve         # functions emulator
```

## Deploy

```bash
npm --prefix functions install
firebase deploy --only functions,firestore,storage
```

The `predeploy` hook in `firebase.json` compiles TypeScript, so
`firebase deploy` alone is enough once dependencies are installed.

## Bootstrapping the first moderator

`setModeratorRole` requires the caller to already be a moderator, so the first
one has to be granted outside the app. From a machine with Admin SDK
credentials (a service account key — do not commit it):

```js
const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.cert(require("./serviceAccountKey.json")) });
admin.auth().setCustomUserClaims("<uid>", { role: "moderator" });
```

The user must sign out and back in — or call `getIdToken(true)` — before the
new claim reaches their token and the Moderation Dashboard button appears.

## Consistency note

Deal completion is now eventually consistent. The deal card updates instantly
because the client wrote the message status; the deal counts, titles and the
listing's `sold` badge land a moment later when the trigger finishes. Item
details streams the listing live so it updates on its own; profile counters
refresh on the next load.
