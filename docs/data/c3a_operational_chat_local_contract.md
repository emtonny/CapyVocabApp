# C3A — local Operational Chat foundation

> 2026-09-15: IMPLEMENTED / LOCAL VERIFIED. C3 overall remains PARTIAL.
> Not wired into app UI/auth runtime; no Supabase adapter/live C3 smoke yet.

## Contract

- Separate `capy_chat_operational.db`, schema v1: conversations/messages only.
  Reuses native/Web SQLite factories, never opens/upgrades Library/AI database.
  No Training/export API or new dependency.
- Every key/query includes `project_ref:user_id`, isolating accounts and
  Staging/Production. Caller must bind owner to Auth; UUID input is not Auth.
- One durable raw-message row is its outbox. Atomic enqueue persists secure
  UUIDs/client key/raw text together. Cached reads/enqueue never await network.
- Offline send requires an already cached active conversation. New conversations
  require C2 RPC; unknown language profiles must be rejected by C3B caller.
- Payload includes only C2 allowed insert columns. No server timestamp override,
  translation, moderation/job state or AI data.
- Explicit single-flight drain: up to 100 due messages, persistent exponential
  backoff, eight-attempt cap. Denied/invalid/exhausted sends become `blocked`,
  retaining raw. C3B must schedule retry deadlines/additional batches and UX.
- Owner-session-bound transport must resolve duplicate sender/client keys by
  reading the existing server row. Current executable transport is test-only.
- ACK/echo merges by ID or sender/client key, checks immutable raw/server time,
  and clears pending only on a valid sent record. Canonical server ID can replace
  pending ID without duplicate. Ordering uses server/client timestamp then UUID.
- Remote timestamp requires timezone; stale metadata cannot regress inbox time.
- Complete membership inventory hides inactive conversations and blocks their
  pending sends. Complete visible history removes absent sent rows while keeping
  unsent local raw. NEVER pass a partial page to reconciliation; C3B must prove
  complete pagination and account for concurrent Realtime/snapshot changes.
- Local watchers serialize SQLite reads and close on store disposal. Relay checks
  owner/disposal before/after awaits; late A responses cannot mutate B's state.
  C3B must actually wire predicates to Auth/network/lifecycle.

Cache is operational application data, not training material, E2EE/encryption,
or proof of fresh remote authorization while offline. C0 privacy/retention,
report/block/account deletion remain product gates. No edit/delete/correction UI.

## Evidence 2026-09-15

```powershell
C:\fulter\flutter\bin\flutter.bat test --no-pub test/features/chat/operational_chat_relay_test.dart
C:\fulter\flutter\bin\flutter.bat analyze --no-pub
C:\fulter\flutter\bin\flutter.bat test --no-pub
```

Targeted **23/23 pass**: real disposable SQLite FFI + fake transport; cold reopen,
Unicode, shape/timezone, owner/project isolation, transaction rollback, lost ACK
after server commit, retry/cap/denied, stale owner, canonical ID/immutable echo/
ordering, inactive/visible history, local streams/dispose, two-owner fake exchange.
Full suite **426 pass + 1 opt-in skip**, exit 0. Analyzer clean after fixing six
new lint infos without suppression; format clean. Not browser/device/live C3 E2E.
No remote calls/migration/deploy/Gemini/Training/commit/push in this increment.

## Next

1. C3B: Supabase adapter/repository/providers, Auth/network/lifecycle binding,
   complete pagination, Realtime attach/reconnect/detach, retry scheduler.
2. C3C: inbox/detail/start-chat from accepted friends, optimistic pending/blocked
   UX and cached-first reads.
3. C3 exit: two real clients on Staging exchange raw, lost-ACK no duplicate,
   reconnect ordering, account isolation and airplane-mode cold restart cache.

C4–C6 translation/learning and T0–T5 Training stay separate/OFF until implemented.
