# ShelfSync: interview notes

## Resume entry (Nov 2026)

**ShelfSync: CMS-driven, offline-first retail app** | Flutter, Riverpod, Dio, Hive, Node | Nov 2026
- Built server-driven UI where a headless CMS controls home-screen blocks (banners, carousels, product grids, scheduled offers), shipping content changes without app releases; unknown block types degrade gracefully for forward compatibility.
- Implemented ETag-based HTTP caching (If-None-Match/304) with stale-while-revalidate, so the store opens instantly and stays usable offline.
- Designed an offline cart with an idempotent, coalescing outbox (UUID op IDs, last-write-wins) that syncs automatically on reconnect.
- Riverpod clean architecture with unit and golden tests; GitHub Actions CI for analyze, test and APK build.

## Likely questions

**Why server-driven UI?** Business teams change offers weekly; a release cycle takes days and users update late. The trade-off is a stricter contract between CMS and app, which I handle with typed sealed blocks, safe defaults for missing fields, and skipping unknown types.

**Why ETags instead of a TTL?** A TTL either shows stale prices or refetches unchanged data. ETags always revalidate but cost almost nothing when content hasn't changed.

**How do you avoid double-applying cart changes?** Ops are "set quantity", not "add one", each with a UUID. The server records applied IDs and acknowledges duplicates without reapplying. The client only deletes acknowledged ops.

**What happens if two devices edit the cart?** Last-write-wins by client timestamp. For a real store I'd move to server time or version vectors, because device clocks drift.

**How would you scale this for an Infosys client?** Put the CMS behind a CDN (ETags work there too), version the layout schema, add feature flags per region or store, and move secrets and base URLs into flavors.

**What would you test next?** Integration tests for airplane-mode flows, and contract tests that validate CMS JSON against a schema before publishing.
