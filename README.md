# ShelfSync

A CMS-driven, offline-first retail catalogue app in Flutter.

The marketing team edits the home screen (banners, category carousel, product grids, store notices, scheduled sale blocks) in a CMS, and the app picks the change up on its next refresh, with no Play Store release. The app keeps working on bad store Wi-Fi: the last layout, products and images are on disk, and cart changes queue up and sync when the network comes back.

## What's inside

```
shelfsync/
├── app/                      Flutter app (Riverpod, Dio, Hive CE)
│   ├── lib/core/             config, ETag cache interceptor, API client, storage, theme
│   ├── lib/features/home/    server-driven UI: block models, block registry, home screen
│   ├── lib/features/catalog/ product model, product detail, shared product widgets
│   ├── lib/features/cart/    local cart, outbox, sync service, cart screen
│   └── test/                 unit tests + golden tests
├── cms/                      zero-dependency Node mock CMS with an /admin editor
└── .github/workflows/ci.yml  analyze, test, build APK, CMS tests
```

## How it works

**Server-driven UI.** `GET /api/layout/home` returns an ordered list of typed blocks (`notice`, `banner`, `carousel`, `product_grid`). `LayoutBlock.fromJson` maps each to a sealed class, and `buildBlock()` is a switch over that sealed type, so the compiler flags any block type without a widget. Block types the build doesn't know (added to the CMS after release) become `UnknownBlock` and are skipped instead of crashing. Blocks can carry `startsAt` / `endsAt`, so a sale banner can be published ahead of time.

**ETag caching.** `EtagCacheInterceptor` stores each GET body with its ETag and sends `If-None-Match` next time. A 304 is turned back into a normal 200 built from the cached body, so the rest of the app never sees 304s. Unchanged content costs a few hundred bytes.

**Stale-while-revalidate.** `LayoutRepository.watchHome()` emits the cached layout instantly, then the fresh one. If the network fails and there is a cache, the user sees the saved layout with a small "Showing saved offers" note, never a blank screen.

**Offline cart with an outbox.** The cart is the local source of truth, so taps update instantly. Every change also goes into an outbox as a `set qty` op with a UUID and a timestamp. Repeated taps on one product coalesce into one op. `CartSyncService` sends the outbox when connectivity returns and removes only the ops the server acknowledges. The server ignores duplicate op IDs (idempotent retries) and applies last-write-wins on timestamps, so a late retry can't overwrite a newer quantity.

**Product grids work offline** because the CMS joins `productIds` to full products server-side, and the app caches the whole response.

## Run it

1. Start the CMS (Node 20+, no install needed):
   ```
   cd cms && npm start
   ```
   Open http://localhost:4000/admin to edit and publish the home layout.
   The first visit from this PC asks you to create the admin password (stored
   as a salted scrypt hash in `cms/data/`, git-ignored). Forgot it?
   `npm run reset-password`, restart, set a new one.

2. Run the app (Android, iOS and web folders are committed):
   ```
   cd app
   flutter pub get
   flutter run
   ```
   Store staff open **Store admin** at the bottom of the home screen to log in,
   reorder/edit/add/remove blocks, schedule them and publish. The ☀️/🌙 button
   in the header switches Light, Dark or "Same as phone".
   The Android emulator reaches your Mac at `10.0.2.2`. For a real phone on the same Wi-Fi:
   `flutter run --dart-define=API_BASE_URL=http://<your-mac-ip>:4000/api/`
   Android blocks plain HTTP by default for release builds; debug builds allow it.

3. Tests:
   ```
   flutter analyze
   flutter test --exclude-tags golden
   flutter test --update-goldens --tags golden   # first time, then commit test/golden/goldens/
   cd ../cms && npm test
   ```

## Deploy the CMS on Render

`render.yaml` is a Render Blueprint for the CMS. In the Render dashboard:
**New → Blueprint →** pick this repo, and enter `ADMIN_PASSWORD` when asked
(it is never committed). On a hosted server the first-time setup screen is
disabled, so this env var is the initial admin password.

Then point the app at it:
`flutter run --dart-define=API_BASE_URL=https://<service>.onrender.com/api/`

The free plan has no persistent disk: layouts published through the admin and
password changes reset to the repo's `cms/content/` and `ADMIN_PASSWORD` on
every redeploy or restart (free services also restart after idling). Commit
content changes, or add a Render disk, copy `cms/content/*.json` onto it, and
point `CONTENT_DIR`/`DATA_DIR` at it.

## Demo script (2 minutes)

1. Open the app online. Point out the notice, banner, carousel and grid all come from the CMS.
2. In `/admin`, change the banner title and reorder two blocks. Publish, pull to refresh: the app changes with no release.
3. Show the expired Diwali banner and the unknown `video_reel` block in the JSON: neither appears in the app.
4. Turn on airplane mode, kill and reopen the app: the store still loads, with the saved-offers note.
5. Add items offline. The cart shows "2 change(s) will save when you're back online". Turn Wi-Fi on and watch it clear.

## Possible next steps

Swap the mock CMS for Strapi or Directus behind the same JSON contract; add a `schemaVersion` gate so old app builds can request a compatible layout; cache-size limits and eviction for the HTTP cache; integration tests with `patrol` for the offline flow.
