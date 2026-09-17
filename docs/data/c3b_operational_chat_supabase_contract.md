# C3B — Operational Chat Supabase adapter

Date: 2026-09-15. **C3B.1 + C3B.2 IMPLEMENTED / LOCAL VERIFIED; C3 PARTIAL.**

## Boundary

`OperationalChatRuntime` is now mounted around the app, but activation requires
`CHAT_RELAY_ENABLED=true`, exact Staging URL, a session and foreground lifecycle.
Default builds do not activate it, even against Staging. Production is rejected
even with the flag enabled. Legacy chat UI remains unchanged. The gateway accepts
only `nxteaznowkfennxpqjmt` and an authenticated
Session whose user matches the SQLite `ChatOwner`. Construction does not send
requests or open a socket. No migration/deploy/remote writes in this increment.

Use a private SDK client with a captured, immutable JWT; never share the global
client's mutable auth state. `isCurrentSession` must compare both account and
token with the current global session, and fail after logout/disposal. Runtime
must dispose/recreate the gateway on account change or token refresh. Every
request checks this predicate before dispatch and after response. Old requests
retain the old token, never the next account's token. Network/timeouts and expired
JWT remain safe retryable failures; forbidden/invalid references/constraints are
denied. Exceptions contain no response body, raw text or credentials.

## Writes and reads

- `send`: insert only C2 client columns; raw text is unchanged. On SQL `23505`,
  read by authenticated sender + durable client key, validate immutable identity
  and return canonical ACK. No UPSERT, edit or delete request. Hidden duplicate
  is denied rather than reinserted. Server owns `sent_at`.
- `openDirectChat`: call `open_direct_chat(p_peer_id)` then read/validate the
  canonical conversation and peer. Server C2 checks mutual accepted friendship
  and profiles; client validation is not authorization.
- `fetchConversations` / `fetchHistory`: keyset `id ASC`, follow pages until
  **empty**, not a short page. Server may cap `limit`. Non-advancing UUIDs,
  malformed rows, wrong owner/conversation or any failed page reject the pull.
  Maximum 1,000 pages per pull, then fail retryable without returning partial
  results. Each HTTP operation times out after 12 seconds by default.
- These pages are **not an atomic database snapshot**. History is merge-only;
  do not feed its result to C3A `reconcileHistory`, which would delete concurrent
  messages. C3B.2 must capture cached sent IDs before pull, call
  `visibleCachedIds` for those IDs only, and prune only verified-missing captured
  IDs after all chunks succeed. Pending/new ACKs must survive. Membership
  deactivation likewise needs a concurrency fence, not a bare inventory sweep.
- `visibleCachedIds`: validate UUIDs, chunks of 50 with keyset pagination even
  within a chunk; filter visible/non-deleted rows in the requested conversation,
  reject unexpected identities. Empty input makes zero requests. This method
  does not itself delete SQLite rows.

## Realtime

`signals` is a lazy broadcast stream with one channel per private gateway and
three C2 table subscriptions (conversations/members/raw messages). Signals are
only `connected`, `changed`, `disconnected`; provider payloads are not exposed or
trusted as cache snapshots. Subscriber callbacks are fenced by session and
channel generation. Last listener cancellation removes the channel; re-listening
creates a fresh one. Disposal awaits removal before disconnect and closes streams.

Local SDK regression found `realtime_client 2.13.0` custom-token connect forcing
a rejoin of an already timed joining Push: `resend` cleared its ref while the
old timer prevented new registration. Fixture observed an empty initial join ref
and no connected signal. The private gateway sets fixed Authorization headers
and disables only its Realtime custom-token resolver; REST remains captured-token
bound. This avoids that initial forced rejoin without modifying SDK packages or
the global client. Refresh/recovery must recreate channels; unexpected socket
loss/reconnect still requires C3B.2/live validation, not assumed from join ACK.

## Verification and next increment

24 adapter tests use MockClient and a local WebSocket server, not Supabase cloud.
47 combined C3A/C3B.1 tests pass, including lost ACK, canonical identity, safe
errors, session change, timeout, short/failed pages, visibility chunks, one
channel for two listeners, stale-event drop and detach/re-listen.

Initial fixtures failed because new PostgREST needs `Response.request`, and
WebSocket teardown raced pending leave; fixtures now preserve HTTP metadata
and wait for leave frames. SDK unsubscribe settles locally after entering its
leaving state; the fixture must not reply to leave into a closing socket.
Do not reuse early failed run results.
Full suite rerun `flutter test --no-pub --reporter json` exited 0 with final
`done.success=true`; `flutter analyze --no-pub` clean. Format check: 2 files,
0 changes. No Web/Android build or live adapter smoke in this increment.

## C3B.2 runtime and cache contract

- SDK auth events invalidate the runtime; the actual SDK session is authoritative,
  not an AsyncValue's previous account. Account/token/lifecycle changes dispose
  the old gateway/coordinator; late responses cannot commit. Same-owner chat cache
  stays independent of token refresh. Owner-keyed inbox/detail providers read only
  SQLite and never instantiate the language-profile repository/notifier.
- Android uses the existing `com.capyvocab.app/network_status` method channel;
  missing/failed plugin fails closed. Web uses `navigator.onLine` from the already
  installed `web` package. Other native platforms attempt background requests and
  rely on safe failure/backoff. Gate timeout is 3 seconds. Expired captured JWT
  behaves like offline: local composition/read remain possible but no send attempts.
- Valid own language profile is read from cache only. Missing/invalid profile
  rejects composition/open-direct; old pending messages remain stored without
  consuming attempts. Drain and deadline query include only the current native
  language. After profile change, other-language pending text is retained, not
  automatically rewritten/sent. Server C2 still authorizes language/friendship.
- Coordinator single-flight checks network, lazily attaches Realtime, drains up
  to 100 eligible messages **before** history pull, and repairs cache separately.
  Scheduler queries durable minimum pending deadline, yields at least 10 ms between
  batches, coalesces invalidations for 150 ms, and respects global 2–300 second
  backoff. Request spam does not reset failed-network backoff. Reconnect/resume
  triggers a fresh pull; disconnected channels get a fresh socket/channel.
- Refresh captures store revision and event generation, exhausts inventory pages,
  then verifies captured+incoming conversation IDs by RLS queries. Atomic apply
  deactivates only captured IDs verified missing and blocks their pending rows.
  Concurrent local open/message/auth/event changes reject the commit.
- History captures sent IDs before fetch, separately verifies captured+incoming
  IDs, merges only verified-visible rows and prunes only captured sent IDs missing
  from verification. Pending and newer ACKs cannot be swept. Store guards before
  and after transaction work roll back superseded history/membership/relay writes.
  A successful membership commit is independent of later failed room history;
  partial history cannot delete that room's existing cache.
- Periodic foreground repair every 30 seconds catches missing/hidden/delete events
  that RLS may not deliver. This initial Staging implementation pulls each active
  cached conversation in sequence (not an incremental production-scale cursor).
  No navigation awaits the flight; no tab/detail operation loads remote profiles.
  Offline detection may wait until backoff deadline; resume recreates runtime.

### Runtime verification and rollout command

75 combined chat tests pass: 23 C3A, 26 gateway (including actual SDK fresh-socket
restart on localhost), 19 coordinator/SQLite and 7 provider/network/auth tests.
Tests cover newer ACK/local open during pull, event fences, transaction rollback,
logout while enqueue waits for SQL lock, unknown/multi-account profiles, token
refresh, lifecycle, durable retry and automatic 101-message batch completion.

Final full suite: 478 pass + 1 opt-in skip, 0 failures; analyzer clean. Final
Staging Web runner command below passed (93.8-second compile), chat/library flags
enabled. Existing flutter_tts Wasm and Cupertino font warnings remain; only
JavaScript Web build verified. Details recorded in `db_status.md` and `chat_DB.md`.
Initial full-suite failure was a fixture's arbitrary 5-second polling deadline
under concurrent compilation; the 101-row test now awaits an explicit completion
signal, still checks all 101 unique server rows and empty durable outbox, and
keeps a bounded timeout. No test skipped or application invariant weakened.

```powershell
.\tool\run_staging_device_smoke.ps1 `
  -FlutterCommand 'C:\fulter\flutter\bin\flutter.bat' `
  -Target web-build -ChatRelayEnabled
```

Runner validates the exact linked Staging ref/name/healthy state, dry-runs only,
obtains the publishable credential without printing it, and removes temporary
define JSON in `finally`. `-ChatRelayEnabled` is optional/default false. Existing
Android device/build targets accept the same switch; Web build does not run the
browser and cannot prove offline shell/device chat. No deploy or migration apply.

**C3C PENDING:** actual inbox/detail/friend UI and Staging two-client/device/Web
smoke, offline cold restart and account switch. C3 exit is not achieved.

Library/scan/AI schema unchanged. Gemini translation C4 and Training remain OFF;
operational chat is never connected to Training/export. Production C1/C2 rollout
and C0 privacy/retention decisions still require their separate gates.
