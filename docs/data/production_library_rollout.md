# Production Library rollout and rollback

> Status: **GATE 3 COMPLETE / PRODUCTION CLOUD CONTRACT VERIFIED**  
> Audit date: 2026-09-11  
> Production project: `CapyVocabApp` (`vmxonxqxrlkssdzsucrg`)

## Scope and safety boundary

This runbook covers the migration-history reconciliation, legacy Photo Note
inventory, M3A/M4.5 rollout and rollback gates. The initial 2026-09-11 audit
was read-only. After explicit owner approvals, Gate 0–2 created an encrypted
backup, verified the schema fingerprint and reconciled the Production migration
ledger; Gate 3 applied M3A/M4.5 and verified the private owner-scoped contract.
The repository was never linked to Production. Runtime fixtures were isolated
and fully removed.

The reusable audit command returns aggregate counts only. It does not print
API keys, user IDs, Photo Note IDs, URLs, or object paths:

```powershell
.\tool\audit_supabase_library_rollout.ps1 `
  -ProjectName CapyVocabApp `
  -ProjectRef vmxonxqxrlkssdzsucrg
```

The harness uses Data API `GET` plus the read-only Storage list endpoint (whose
transport verb is `POST`). It has no insert, update, delete, upload, migration,
bucket-update, or policy-update operation.

## Audit result

| Check | Staging | Production pre-Gate 3 | Production post-Gate 3 |
| --- | ---: | ---: | ---: |
| `photo_notes` rows | 5 | 0 | 0 |
| Public URL rows | 0 | 0 | 0 |
| Normalized object-path rows | 5 | 0 | 0 |
| Missing/mismatched `media_assets` relation | 0 | N/A | 0 |
| Storage objects | 10 | 0 | 0 |
| Legacy Storage objects | 0 | 0 | 0 |
| Unreferenced Storage objects | 0 | 0 | 0 |
| Bucket public | false | true | false |
| `media_assets` exists | true | false | true |
| Inventory truncated | false | false | false |

Production had no Photo Note row or object before apply and still has none
after fixture cleanup, so no legacy backfill was needed.

## Migration history reconciliation

Read-only `migration list --project-ref` found:

- 14 versions shared by local and Production.
- Baseline `20260725204011` exists only in local history even though the
  Production schema necessarily contains its tables used by later migrations.
- Four Production-only versions have the same business names as four later
  local versions.
- After history reconciliation, only M3A `20260903120000` and M4.5
  `20260910120000` should remain local-only.

| Production version | Local canonical version | Semantic comparison |
| --- | --- | --- |
| `20260827134123` | `20260827203358` | Same statements; local removes duplicate semicolon and adds rationale |
| `20260828104338` | `20260828173421` | Same final grants/schema; local adds transaction and explicitly revokes `service_role` before granting the same final privileges |
| `20260828104528` | `20260828174457` | Same revoke/grant; local adds transaction and removes duplicate semicolon |
| `20260829082840` | `20260829152311` | Same statements; remote has one trailing empty statement |

The SQL was fetched to an OS temporary directory, compared, and removed. After
explicit approval, history repair was executed on 2026-09-11. Production now
matched local through `20260829152311`; Gate 3 then applied M3A
`20260903120000` and M4.5 `20260910120000`. Production history now matches
local 21/21.

## Production gates

### Gate 0 — release and backup readiness

**COMPLETE — 2026-09-11.** The Docker-based dump path failed closed because
Docker was unavailable. The fallback used installed PostgreSQL 18 tools and a
temporary Supabase login entirely in process memory. The successful backup is:

`%LOCALAPPDATA%\CapyVocabApp\production_backups\20260911T105509Z`

It contains encrypted public schema, full public custom dump and pre-repair
migration history. Windows DPAPI `CurrentUser` encryption was round-trip
verified against SHA-256, `pg_restore --list` passed, plaintext temp files were
removed, and the restore constraint is the same Windows user/profile context.

1. Keep Production builds on `LIBRARY_SYNC_ENABLED=false`.
2. Freeze new Photo Note cloud writes for the maintenance window.
3. Export Production schema/data to an operator-approved encrypted location;
   never commit the dump. Capture a Storage inventory separately.
4. Record current app release, migration list, bucket policy and audit JSON.
5. Verify a rollback app build with sync disabled can still sign in and use the
   local Library.

Exit criterion: backups are recoverable and the rollback build is identified.

### Gate 1 — repeat the read-only inventory

**COMPLETE — 2026-09-11 10:55:59Z.** Production still had 0 Photo Note, 0
Storage object, complete inventory, public bucket and no M3A tables immediately
before ledger repair. Therefore no conditional backfill ran.

Run the audit harness immediately before any history or schema change.

Exit criterion: `complete_inventory=true`. If legacy rows/objects remain zero,
continue. If not, stop and run the conditional backfill.

### Conditional legacy backfill

Do not fabricate scan JSON or training labels for old records. For each legacy
Photo Note, an approved admin-only, resumable job must:

1. Parse the public URL into an owner-scoped old object path and reject owner
   mismatch or unsupported external URLs.
2. Download the old object, decode dimensions/MIME, and compute byte size and
   SHA-256.
3. Allocate a stable MediaAsset UUID and upload the same bytes to
   `{userId}/{mediaAssetId}/display.{extension}`.
4. Insert `media_assets` with `capture_source='migration'`; leave
   `primary_scan_run_id` null when no real scan evidence exists.
5. Update `photo_notes.media_asset_id` and replace `image_path` with the private
   display object path.
6. Download through an authenticated signed URL and verify hash/size before
   marking the item complete.
7. Keep the old object until the new client and all row/object checks pass.
   Deleting old objects is a separate approved retention action.

The job must keep a local encrypted checkpoint/receipt because Storage copy and
Postgres updates cannot form one transaction. It must be idempotent by Photo
Note ID and content hash. No job is needed while both legacy counts remain zero.

### Gate 2 — history-only reconciliation

**COMPLETE — 2026-09-11 after explicit owner approval.** The fingerprint
confirmed all 15 baseline tables, the subscription uniqueness constraint,
AI-scan ledger/function/final service-role privileges, all three circuit-breaker
functions, and absence of M3A/M4.5 tables.

Only after a schema fingerprint confirms the baseline and four canonical
migrations are materially present may an operator approve these history-only
changes:

```powershell
# Executed against the explicit Production project ref.
npx.cmd supabase migration repair --project-ref vmxonxqxrlkssdzsucrg `
  --status reverted 20260827134123 20260828104338 20260828104528 20260829082840

npx.cmd supabase migration repair --project-ref vmxonxqxrlkssdzsucrg `
  --status applied 20260725204011 20260827203358 20260828173421 `
  20260828174457 20260829152311
```

Post-repair `migration list --project-ref` confirmed the only local-only
versions are `20260903120000` and `20260910120000`. Production-targeted
`db push --dry-run` proposed exactly those two files. Post-repair aggregate
audit confirmed product schema/data and bucket state were unchanged.

History-repair rollback is the exact inverse status mapping; it changes only
the migration ledger, never schema objects. Record before/after output so the
ledger can be restored deterministically.

### Gate 3 — dry-run and apply

**COMPLETE — 2026-09-11 after explicit owner approval.** Production-targeted
push applied exactly M3A `20260903120000` and M4.5 `20260910120000` without
relinking. Migration history is 21/21 and post-apply dry-run is up to date.

Post-apply verification covered:

- Full Library flow using the real SQLite store/worker/gateway: private upload,
  normalized raw JSON/evidence, metadata pull to a second SQLite database,
  permanent purge and fixture cleanup.
- Two authenticated fixture users: owner row/read/upload and signed URL passed;
  cross-user row reads returned empty, cross-user insert returned 403, and
  cross-user Storage read/upload returned 400.
- Final aggregate audit: M3A present, bucket private, 0 rows/objects/legacy or
  unreferenced objects. Auth fixture marker count was 0.

The first cross-user harness run reported a false failure because PowerShell
wrapped a decoded empty JSON array as one `$null` element. Raw JSON comparison
proved isolation and the corrected rerun passed. The aggregate audit received
the same empty-table fix and was regression-checked against populated Staging.

A sync-enabled Production app build/release remains a separate rollout action;
the default build flag is still `LIBRARY_SYNC_ENABLED=false`.

## Operational rollback

Rollback is fail-forward and preserves newly written data:

1. Stop rollout and distribute/restore the build with Library sync disabled.
2. If private-media reads regress, temporarily restore the old bucket public
   flag and old read policy only after a security review. This restores legacy
   availability but reopens public access, so it is an emergency measure with
   an expiry time.
3. Do not drop normalized tables, change-event rows, or copied objects while
   any client may have written them. Preserve them for diagnosis/retry.
4. Fix the reader/RLS issue, verify signed download with two users, then make
   the bucket private again.
5. Reverting migration-history status is allowed only when no schema apply was
   performed; otherwise use a reviewed forward migration.

Success means local/offline Library remains available throughout, no public
URL is required by the active client, owner isolation passes, and Production
history has no unexplained remote/local-only version.
