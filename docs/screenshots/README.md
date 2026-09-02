# Screenshots

The README's hero row expects four files here. Names matter — the `<img>` tags
reference them directly:

| File | Screen | What to capture |
| --- | --- | --- |
| `feed.png` | Home | The marketplace feed with the filter panel open, showing category pills and a few listings with real photos |
| `item.png` | Item details | A listing with several photos, so the gallery counter and thumbnail strip are visible |
| `deal.png` | Chat | A conversation with a deal card in it — ideally `accepted`, so the reserved state and the seller's complete button both show |
| `profile.png` | Profile | A profile with a non-zero rating and a reputation title above *Freshman Trader* |

Capture at a consistent device size. A tall phone frame (Pixel 8 / iPhone 15) keeps
the four images the same height in the row.

```bash
flutter run                       # then use the device's own screenshot gesture
# or, from a running session:
flutter screenshot --out=docs/screenshots/feed.png
```

Seed a handful of listings with photos first — an empty feed makes a poor hero image.
