# StudySwap

A student-only campus marketplace for textbooks, notes and kit — built in Flutter on
Firebase, with a reputation system that survives a hostile client.

[![CI](https://github.com/rayen011/study-swap/actions/workflows/ci.yml/badge.svg)](https://github.com/rayen011/study-swap/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20·%20Firestore%20·%20Storage%20·%20Functions-FFCA28?logo=firebase&logoColor=black)
![Tests](https://img.shields.io/badge/tests-82%20Dart%20%C2%B7%2070%20rules-2C6A45)

<!-- Drop captures into docs/screenshots/ with these names and the row renders. -->
<p align="center">
  <img src="docs/screenshots/feed.png" width="200" alt="Marketplace feed with filters">
  <img src="docs/screenshots/item.png" width="200" alt="Listing detail with photo gallery">
  <img src="docs/screenshots/deal.png" width="200" alt="Deal request inside a chat">
  <img src="docs/screenshots/profile.png" width="200" alt="Profile with reputation title">
</p>

---

## What it does

Students list what they no longer need, find it near them, and hand it over in person.
The part that makes it more than a CRUD app is the **deal loop**:

> Buyer opens a deal on a listing → seller accepts, which reserves the item → they meet
> and the seller marks it complete → the listing goes sold, both parties' deal counts
> rise, and their reputation titles move up → each can leave one review, once.

Every step after "accepts" is enforced server-side. A user can't mark someone else's
deal complete, can't review the same deal twice, and can't touch their own rating.

### Features

- **Marketplace feed** — server-side filtering by category and condition, three sort
  orders, paginated 20 at a time, with debounced search over the loaded window
- **Listings** — up to five photos with compression, live status (active / reserved /
  sold), favourites
- **Chat** — realtime messaging with unread counts, and deal requests as a first-class
  message type
- **Reputation** — ratings, review history, and titles that climb from *Freshman Trader*
  to *Campus Pro* with completed deals
- **Credits** — bidding power earned by completing trades, never bought and never cashed
  out. The foundation of an auction feature; see *Known gaps*
- **Auctions** — a listing can be sold to the highest bidder instead of at a fixed price,
  with a hidden reserve, anti-snipe extensions, and a scheduled function that closes the
  floor on time. Bidding costs credits to hold, so an unbacked bid is arithmetically
  impossible. The sell form offers it as a mode; the room is a full-screen route with the
  tab bar gone — deliberately a place you enter, not a sixth tab
- **Moderation** — report users or listings; moderators get a queue, and can hide a
  listing or suspend an account

## Architecture

Feature-first, with a repository layer between Firestore and the UI. Cubits hold state;
no widget imports `cloud_firestore`.

```
lib/
├── core/
│   ├── constants/   listing vocabulary (category, condition, status, sort)
│   ├── models/      Listing, AppUser, ChatSummary, Message, Review, Report
│   ├── router/      GoRouter config, route guards, splash gate
│   ├── theme/       palette, type scale, ThemeData
│   ├── utils/       form validators
│   └── widgets/     shared UI
└── features/
    └── <feature>/
        ├── data/    repositories — the only place Firestore is touched
        ├── logic/   cubits and states
        └── screens/
functions/           Cloud Functions (TypeScript)
```

**Models, not maps.** Every repository returns typed models built through a shared
parsing layer, so a document written by an older build degrades to sensible defaults
instead of throwing somewhere up the widget tree. Route arguments are typed too.

**Auth is Firebase's answer, not a local flag.** `AuthCubit` subscribes to
`authStateChanges()`. It stays in `AuthInitial` until that stream speaks — the router
shows a splash for exactly that window — and `AuthLoading` deliberately means something
different, so an in-flight sign-in doesn't bounce the user off the form.

## The security model

The interesting constraint in a client-heavy app: **nothing the client says about itself
can be believed.**

| Concern | How it's handled |
| --- | --- |
| Moderator access | An auth custom claim, never a Firestore field — a client-written field isn't an authorization decision |
| Ratings, deal counts, titles | Owned by Cloud Functions; they appear in no client-writable shape in the rules |
| Credit balances | Same, and for a sharper reason — credits are what a bid will cost, so a self-written balance is a self-written bid ceiling. The one exception is signup, where the rules accept a single fixed opening value |
| Auctions and bids | No client writes any part of either. Bidding is a callable, closing is scheduled, and both run as the Admin SDK |
| Shill bidding | A seller cannot bid on their own auction, checked inside the same transaction that records the bid |
| Opening a floor | A callable that checks the listing is yours, active, and not already up. The rules pin a client-written listing to `saleMode: 'fixed'` and forbid `auctionId` outright |
| Hidden reserve prices | Rules can deny a document but cannot hide a field, so the reserve lives in a subcollection only the seller can read. The auction itself carries whether one exists, never what it is |
| One review per deal | Deterministic document ids, create-only. A second review collides rather than overwriting |
| Deal transitions | Accept, decline and complete all require `uid() == dealData.sellerId` |
| Suspension | Rules block writes; a trigger disables the Auth account so reads stop too |
| Listing photos | Storage rules check ownership from the path — Storage rules can't read Firestore |

[`firestore.rules`](firestore.rules), [`storage.rules`](storage.rules) and
[`functions/`](functions/) are all in the repo — and all of it is tested.
[`rules-tests/`](rules-tests/) runs 94 assertions against the Firebase emulators, from
"a user can't write their own rating" to "only the seller can complete a deal".

Those tests were themselves mutation-tested: rules were deliberately loosened to
confirm the suite noticed. It did, including a case that wasn't predicted. An
`assertFails` test passes just as happily when the operation fails for the wrong reason,
so a green run on a security suite proves less than it looks like.

## Tech stack

**Flutter** · flutter_bloc (Cubit) · go_router · equatable · google_fonts ·
cached_network_image · image_picker
**Firebase** · Auth · Cloud Firestore · Cloud Storage · Cloud Functions (TypeScript)
**Testing** · flutter_test · bloc_test · mocktail · GitHub Actions

## Running it

```bash
flutter pub get
```

The app needs its own Firebase project — the committed `firebase_options.dart` and
`google-services.json` point at mine.

```bash
dart pub global activate flutterfire_cli
flutterfire configure          # rewrites firebase_options.dart and google-services.json
```

Then enable **Email/Password** auth, and deploy the backend — the feed needs its
composite indexes, so it will error until they exist:

```bash
npm --prefix functions install
firebase deploy --only firestore,storage,functions
```

```bash
flutter run
```

### Seeding demo data

The feed hides your own listings, so a project with one account looks empty no
matter how much you post. To get something to look at:

```bash
npm --prefix tools install
npm --prefix tools run seed
```

Creates three demo members, twelve listings, a conversation with a completed
deal, and two reviews. Needs a service account key — see
[tools/README.md](tools/README.md).

### Becoming a moderator

`setModeratorRole` requires the caller to already be one, so the first has to be granted
outside the app. See [functions/README.md](functions/README.md). Sign out and back in
afterwards — a new claim only reaches an existing token on refresh.

## Tests

```bash
flutter test                              # 212 Dart tests
npm --prefix rules-tests run emulate      # 94 security rules tests (needs JDK 21+)
npm --prefix functions run test:emulate   # 71 Cloud Functions tests (needs JDK 21+)
```

The cubit suites use `bloc_test` with mocked repositories; the rest cover model parsing
(including legacy and malformed documents) and form validation. The rules suite runs
against the Firestore and Storage emulators — see
[rules-tests/README.md](rules-tests/README.md).

The functions suite runs the real Admin SDK against a real Firestore emulator rather
than a mocked one. What is worth testing about the auction closer is that a transaction
applies whole or not at all — a bidder whose auction closed but whose stake stayed
locked has lost credits to a bug — and a mock would happily lie about that. It is also
where two people bidding the same amount in the same instant can actually be raced
against each other, which is the failure the whole feature turns on. Those tests were
mutation-tested too: four separate loosenings of the closer and the bid function each
broke exactly the tests written to catch them.

One test reads a different language. The credit amounts live in
[`functions/src/credits.ts`](functions/src/credits.ts), because the server is what
writes balances, but the app needs the same numbers to explain them — so
`credit_rules_test.dart` parses the TypeScript and fails if the Dart mirror drifts, and
also checks the opening balance against the literal in `firestore.rules`. Duplication
that buys something gets a test instead of a refactor.

Several encode invariants rather than behaviour — an unrecognised report status must
default to *pending* so a report can't silently vanish from the moderation queue, and
every category the sell form can write must survive the round trip back through the feed
filter. That last one exists because it didn't, once.

## Trade-offs

Worth being explicit about the decisions that went the "wrong" way on purpose.

**Pagination grows a window instead of using cursors.** A cursor means one subscription
per page and merging emissions by hand. Re-subscribing with a larger limit keeps the feed
a single live query and lets Firestore serve seen documents from cache. It costs one
re-read per *load more* — a fair price for realtime at a 20-item page.

**Price and text filters are client-side.** Firestore requires the first `orderBy` to be
the range field, so a server-side price filter would silently override the user's chosen
sort — ask for newest, get cheapest-first. Full-text search needs Algolia or Typesense.
The results bar says "12 of 40 loaded" rather than implying it searched everything.

**Deal completion is eventually consistent.** The deal card updates the instant the
client writes the status; counts, titles and the sold badge land when the trigger
finishes. Correctness beat immediacy — the alternative was trusting the device.

**No dark mode yet.** The design is built on hard black borders and offset black shadows
against white. A mechanical token swap gives black shadows on a black ground; what a
neo-brutalist shadow becomes in the dark is a design decision, not a find-and-replace.

## Known gaps

- University email verification isn't enforced, so "Verified Student" is aspirational
- No push notifications — the bell icons are honest about having nothing behind them
- `applicationId` is still `com.example.studyswap`, and release builds sign with the
  debug key
- Meetup location is a placeholder rather than a real campus picker
- Credits are earned but not yet spent — bidding itself is the next piece of work
- The auction handoff isn't built: a won auction sets a winner but doesn't yet open the
  chat and drop in the deal card
- No push notifications, which an auction needs more than anything else here — "you've
  been outbid" is most of what makes bidding worth returning to
- No scheduled function runs on the Spark plan, so the auction closer needs Blaze

---

Built by [@rayen011](https://github.com/rayen011) as a portfolio project.
