# M4.5 Cloud metadata pull

Status: **IMPLEMENTED, STAGING VERIFIED AND ANDROID UX VERIFIED** (2026-09-11).

## Runtime flow

```text
sign-in / Cloud Backup OFF->ON / app resume
  -> LibrarySyncCoordinator single-flight
  -> drain local upload + privacy-purge work first
  -> read owner SQLite cursor
  -> RPC pull_library_delta(cursor, limit=100)
  -> RLS returns only owner change events plus current normalized rows
  -> one SQLite transaction:
       apply hard-delete tombstones first
       merge cloud metadata/raw JSON/vocabulary
       preserve pending/local-only local edits
       advance owner cursor
  -> if a hard delete arrived, run local media/lineage purge maintenance
  -> notify owner-scoped Library streams
  -> if the bounded pull reports has_more, continue in the same single-flight
     coordinator without waiting for another resume/navigation event
```

Home, Library navigation and detail rendering remain SQLite-only. They do not
trigger profile or Library cloud requests.

## Media rule

Pull imports `MediaAsset` metadata and a deterministic app-private target path,
but it does not call Storage download. A new-device Photo Note therefore appears
immediately with vocabulary/JSON and a missing-image placeholder. Only the
existing explicit **Tải ảnh từ cloud** action downloads the private object,
validates owner/path/size/SHA-256 and atomically writes the target file.

The Library storage summary does not treat remote `byte_size_display` metadata
as local usage. It lists distinct owner-scoped media retained by active/Trash
Photo Notes, stats the app-private files, and sums their actual lengths. Cards
and detail notices distinguish **Ảnh trên máy**, **Ảnh trên cloud**, and
**Thiếu ảnh**. This check never downloads media.

## Cursor and conflict rules

- `library_change_events.sequence` is a server-generated global monotonic
  cursor; RLS filters it to `auth.uid()`.
- SQLite v3 stores `last_sequence` in `library_pull_cursors`, keyed by user.
- Applying rows and advancing the cursor is atomic. A failed merge replays the
  same batch.
- A permanent-delete receipt wins over any snapshot with the same Photo Note
  ID and prevents resurrection.
- A local Photo Note whose sync state is not `synced` is not overwritten. Its
  eventual upload creates a later server event.
- Scan evidence/detections are append-only locally. Annotations are merged only
  when that annotation has no unfinished local operation.
- Hard deletes immediately fail-close related training examples and invalidate
  models trained from the source; existing deletion maintenance then removes
  the app-private file and source rows.

## Privacy and rollout

- Change events retain identifiers, operation and server timestamp only; they
  do not duplicate JPEG bytes or raw Gemini JSON.
- The RPC is `SECURITY INVOKER`, validates bounds, and reads only owner rows
  under existing RLS.
- Pull is gated by authenticated owner, Cloud Backup consent and
  `LIBRARY_SYNC_ENABLED=true`.
- Migration `20260910120000_add_library_cloud_pull_feed.sql` is additive and is
  applied on Staging only. Production remains unchanged.

## Verification

The Staging live-owner smoke uses two independent SQLite databases to model two
devices. Device A uploads one aggregate and private JPEG. Device B pulls the
metadata/raw JSON/vocabulary into SQLite, advances its owner cursor, creates no
outbox operations and has no local JPEG. After A permanently purges the cloud
aggregate, B receives the delete receipt and removes its local source rows.

The smoke also verifies cleanup of the temporary Auth user, normalized rows,
Storage objects and change-feed events. Migration history is 21/21 and the
post-apply dry-run reports the linked Staging database is up to date.

On CPH2375, a Staging APK installed with `adb install -r` preserved the SQLite
and JPEG checksums. With five rehydrated notes and one explicitly restored JPEG,
the UI reports `1/5 ảnh trên máy • 114.2 KB` and `4 trên cloud`. Opening a
cloud-only detail exposes the manual download CTA while the media directory
remains at one JPEG. The full Flutter suite passes 346 tests with one opt-in
live test skipped by default, the analyzer is clean, and the Android Staging
APK builds with Library sync enabled.
