# C2 — Operational Chat schema contract

> 2026-09-15: IMPLEMENTED / LOCAL + STAGING REST/REALTIME VERIFIED after approval.
> Staging history 23/23/up to date; Production not applied.
> Canonical SQL: `supabase/migrations/20260915120000_add_operational_chat_security.sql`.

## Scope and compatibility

C2 is additive. Legacy `public.chat_messages` and its existing client API remain
unchanged, including writes and publication. Staging read-only audit found zero
legacy messages and zero friendship rows, so no backfill is required. Legacy
deprecation is a later client-cutover step, not a physical read-only restriction
in this migration: that would break the currently used chatbot datasource.

No Training table, exporter, trainer credential, Gemini call, Flutter code,
SQLite schema or Library database is introduced or changed here. These five
tables are purely Operational; their contents must not feed Training.

## Tables and authority

| Table | Purpose | Authenticated client authority |
| --- | --- | --- |
| `chat_conversations` | Canonical direct pair, server timestamps | Active-member SELECT; creation via RPC only |
| `chat_members` | Membership and inactive state | Active-member SELECT; no direct mutation |
| `chat_operational_messages` | Exact raw text, language, idempotency key | Active-member SELECT; restricted-column INSERT for self |
| `chat_translations` | Shared provider translation and job state | Member SELECT only; trusted service writes |
| `chat_corrections` | Separate human-proposed correction | Member SELECT; restricted proposal INSERT by other member |

All five tables use RLS. Anonymous access is denied. Service writes still obey
constraints and triggers. Authenticated clients cannot update/delete raw text,
write translations, or accept/reject corrections directly.

`open_direct_chat(p_peer_id)` binds actor identity to `auth.uid()`, requires
both directed friendship rows accepted and both language profiles, orders the
pair canonically, and creates the conversation plus two members atomically.
Repeat/reversed calls return the same conversation. Inactive membership is not
silently reactivated by the RPC.

Existing friendship RLS alone would let a sender forge `accepted`. A new trigger
blocks that escalation, while preserving the current recipient-accept followed
by mirrored INSERT/UPSERT flow. Friendship identity cannot be rewritten.

## Message and derived-data invariants

- Raw text is stored verbatim, non-whitespace, 1–4000 characters, `vi`/`en`.
- The sender must be an active member, the peer must remain active, and the
  source language must match the sender's self-declared native language.
- `(sender_id, client_generated_id)` is unique. C3 must treat retry conflict as
  the existing message, rather than generating a new ID on each attempt.
- `sent_at` is server assigned; client-supplied timestamps cannot override it.
  Raw content, identity and creation timestamps cannot subsequently be rewritten.
- Hidden/deleted messages hide translations and corrections from client reads.
- Translation identity is unique on message/target/version; target differs from
  source. A successful result requires text and metadata; successful content is
  immutable. C4 still needs atomic claim, worker retries and quota control:
  uniqueness alone does not prove one Gemini call.
- A correction is authored by the other active member, whose native language
  matches its target. Proposed text remains separate from provider output.
  Final acceptance/rejection must name the raw-message sender; C6 must expose
  a server-authorized resolver, not a client table UPDATE.

Indexes cover owner membership, ordered message reads, translation retries and
correction reads. All five tables are added explicitly to `supabase_realtime`.
Default replica identity is retained rather than FULL, avoiding raw text in old
DELETE payloads. Native tests verify catalog membership. Staging smoke now also
verifies five-table WebSocket subscriptions and raw/derived member-only relay;
client reconnect and device lifecycle behavior remain C3 checkpoints.

## C0 decisions still required

Raw edit/delete, retention, report/block, and account-deletion product policy
remain pending. Foreign keys follow the existing account-cascade convention;
approve or revise that policy at C0 before exposing deletion UI or Production
rollout. C2 does not implement scheduled retention or client delete APIs.

## Verification and rollout

```powershell
pwsh -NoProfile -File .\tool\test_chat_operational_schema.ps1
pwsh -NoProfile -File .\tool\audit_staging_chat_legacy.ps1
pwsh -NoProfile -File .\tool\run_staging_operational_chat_smoke.ps1
npx supabase db push --project-ref nxteaznowkfennxpqjmt --dry-run
```

Actual results on 2026-09-15:

- Native PostgreSQL 18 isolated cluster: **47 SQL/RLS checks passed**, transaction
  rolled back, cluster stopped and temporary files removed; zero remote writes.
- Staging audit: legacy columns verified, 0 messages, 0 friendship rows; only
  counts emitted, no message content or credentials logged.
- Staging dry-run proposed only `20260915120000_add_operational_chat_security.sql`.
  At the local-only checkpoint remote had 22 migrations/local 23.
- After explicit user approval, a fresh public/private DPAPI backup was verified:
  archive 146,004 bytes at
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20260915T113034Z-c9e9c096`.
  Auth/Storage/object bytes excluded; restore requires the same Windows profile.
- Exact C2 apply succeeded; migration list 23/23, post-apply dry-run up to date.
- Live smoke: 10 groups passed with three synthetic accounts and real native
  WebSockets. All five subscriptions ready for all three sessions; A/B received
  raw before translation and shared derived events. Outsider REST reads empty
  and zero Realtime events in the bounded test window; anonymous reads denied.
  Friend acceptance/mirror compatibility, atomic RPC, idempotency, immutable
  content, service-only provider writes, correction actor, held/inactive gates
  passed. Fixture Auth remaining zero and all baseline counts preserved.
- C1 regression: seven groups passed/cleanup zero. Library audit: five notes,
  ten normalized private objects, no legacy/missing/mismatched/unreferenced paths.
  Post-cleanup legacy/friend audit both zero. Production was not accessed.

Bootstrap intentionally contains minimal existing schema contracts and synthetic
users, not the full Supabase stack. Tests exercise roles/RLS, RPC atomicity,
friendship escalation, identity spoofing, idempotency, Unicode/empty/size limits,
service-only writes, immutable derived content, outsider/inactive visibility,
anonymous denial and legacy compatibility. They do not replace the separate
live REST/Realtime smoke. No real Gemini output or training data is used.

Runner uses the installed native PostgreSQL tools, without Docker/dependencies.
On Windows, startup waits for the pg_ctl parent only, not the background server
process tree; cleanup validates the exact generated temporary directory.

Staging C2 gate is verified. C3 can implement client relay/cache against this
contract; UI, local outbox, offline restart, ordering/reconnect and device E2E
are not delivered by this backend smoke. Production requires separate approval
and C0 product-policy review. Translation worker/single-flight remains C4;
successful synthetic translation does not claim an actual Gemini call.
