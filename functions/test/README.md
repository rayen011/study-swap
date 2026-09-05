# Cloud Functions tests

```bash
npm --prefix functions run test:emulate   # starts an emulator and runs them
npm --prefix functions run typecheck      # type-checks src and test together
```

Needs a JDK on `PATH` — the Firestore emulator is a Java process, and
firebase-tools wants 21 or newer.

## Why these run against a real emulator

The Admin SDK talks to an actual Firestore, and the tests read back what it
wrote. A mocked Firestore would pass every one of them while telling you
nothing, because what is worth checking here is exactly what a mock invents:

- a transaction applying **whole or not at all**. An auction that closed but
  left the winner's stake locked has taken credits from somebody by accident
- reads happening **before** writes, which Firestore requires and a mock does
  not
- `settleAuction` being **safe to call twice**, which matters because a
  scheduled function is retried on failure and can overlap with itself
- two bids **racing each other for real**. `placeBid` is tested by firing two
  at one auction concurrently and asserting the invariant afterwards — one
  leader, one standing bid, and nobody holding credits against a bid that no
  longer stands. A mock cannot lose that race, so it cannot prove the
  transaction wins it

`npm test` on its own refuses to run: without `FIRESTORE_EMULATOR_HOST` the
Admin SDK would reach for a real project, and these tests delete every
document between cases.

## What they do not cover

The trigger wrappers — `onDocumentCreated`, `onSchedule` and friends. Those are
thin: they unpack an event and call something else. The something else is what
is tested here, which is why `settleAuction` is exported separately from
`closeExpiredAuctions` rather than living inside it.
