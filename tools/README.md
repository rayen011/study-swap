# tools

Scripts that operate on a live Firebase project with admin credentials.

## Seeding demo data

Run from the **project root**:

```bash
npm --prefix tools install     # first time only
npm --prefix tools run seed    # add demo data
npm --prefix tools run reseed  # remove it, then add it again
npm --prefix tools run clean   # remove it and stop
```

`--prefix tools` points npm at this folder's `package.json`. Running
`npm run seed` from the root fails with *Missing script* — the root of a
Flutter project has no `package.json`. From inside `tools/`, plain
`npm run seed` works.

### What it creates

- **3 demo members** with varied reputation, so titles and ratings have
  something to show
- **12 listings** across every category and condition, one of them sold
- **A conversation** containing a completed deal
- **2 reviews**, one in each direction

### Why you need it

The marketplace feed hides your own listings — they belong in Collection. So a
project with a single account shows an empty feed no matter how much you post.
Demo members give the feed something to display, and give the README's
screenshots a populated app to photograph.

The demo members exist only as Firestore profiles, with no Auth accounts. You
can't sign in as them, and don't need to — the app only ever reads them.

### Getting the key

`seed.mjs` needs admin credentials:

Firebase console → **Project settings** → **Service accounts** →
**Generate new private key** → save as `tools/serviceAccountKey.json`.

That file grants full administrative access to the project. It's gitignored
here and at the repo root; keep it that way.

### Removing it again

`npm --prefix tools run clean` deletes only:

- listings whose `userId` is one of the `demo_` accounts
- reviews written about those accounts
- chats whose document id starts with `demo_`, and their messages
- the three `demo_` profiles themselves

Your own account, your listings, your chats and anything else you created by
hand are matched by none of those and are left alone. `reseed` runs the same
removal and then seeds again.

If you'd rather do it in the Firebase console, every demo document is
identifiable by the `demo_` prefix on its `userId`, `toId` or document id.

## Backfilling credits

```bash
npm --prefix tools run backfill-credits            # show what would change
npm --prefix tools run backfill-credits -- --apply # write it
```

Credit balances are written by Cloud Functions and by the signup rules, and
neither reaches backwards — a profile created before credits existed has no
balance and reads as zero in the app until its owner completes another deal.
This converts an existing trading history into an opening balance, once.

Unlike the seeder, it touches real accounts, so it prints the plan and writes
nothing unless you pass `--apply`. Accounts that already have a balance are
skipped, so rerunning it is safe.

Past deals are credited at the buyer rate, the lower of the two: a profile
records how many deals somebody completed, not which side of each they were
on, and under-awarding a bid ceiling is the harmless direction to be wrong in.
