# C3C — Operational raw chat UI / smoke checkpoint

Updated: 2026-09-17. **C3 COMPLETE on exact Staging.** UI + accepted Friends list,
guarded Web/Android bidirectional raw relay, cold Web restore, Android offline enqueue,
cold restart/reconnect/ACK single-render and physical A→B→A account isolation are
VERIFIED. C4/C5 bilingual translation/correction are not part of this result.

Latest C3 exit checkpoint: relay/coordinator/screen tests pass 57/57 for lost response,
same-key retry, late owner ACK, account isolation and inactive membership. Live Staging
synthetic smoke passes 10/10 with retry no-duplicate, membership inactive fail-closed,
real Realtime/RLS and cleanup baseline preserved (`fixture_count_remaining=0`). The
runner exact-count guard now accepts PostgREST 200/206 only with a parseable exact
`Content-Range`. Android A→B→A is verified: B loaded `en→vi` with a distinct owner
scope; after manual A sign-in, A loaded `vi→en` and reopened its original cached
conversation/history/composer while both radios were disabled. B Cloud Backup remained
OFF; its consent dialog was dismissed with `Để sau`. Network was restored to the
pre-check state and current-process chat/sync/error matches were 0. Final analyzer is
clean; full suite is 495 pass/1 existing opt-in skip/0 failure.

Latest live receive checkpoint: after the corrected APK install, the user sent the
requested fresh Web→Android message and confirmed it appeared on the phone. A next-day
5,485 ms cold launch reopened the cached detail, chat SQLite updated at 18:37 and the
current process had no matching sync/Failed/Exception log. Historical logcat had
rotated, so this combines explicit live user observation with new persistence/runtime
evidence rather than claiming unavailable old logs. No extra test message was sent.

Latest Android APK parity checkpoint: the installed 13:22 artifact predated the
20:26–20:58 shared sync fixes. Guarded exact-Staging rebuild passed (110.2 s,
dry-run up-to-date/no apply); `install -r` preserved both SQLite DBs and 3 JPEG.
Cold launch passed in 7,569 ms and the detail rendered 7 bubbles versus 3 before
replacement, recovering missing remote history with no matching sync/Failed/Exception
log. A fresh post-install Web→Android Realtime event is still a separate live check.

Latest raw exchange checkpoint: Web→Android and Android→Web both render. Safe table
stats report estimates of 1 conversation, 2 members, 2 operational messages and 0
translations/corrections. The stale Web side had three confirmed client causes:
hidden-tab lifecycle/timer gating, Realtime connect superseding an in-flight pull,
and PostgREST 2.9.1 descending default order conflicting with an ascending UUID `gt`
cursor. After the fixes, a cold Web reload issued conversation/history HTTP 200 reads
and the detail showed both owner-scoped raw bubbles. No message payload/token/UID was
printed by the diagnostic checks. At that checkpoint C3 was still PARTIAL; the final
A→B→A and cross-layer gates documented above supersede that interim status.

Latest Android reconnect checkpoint: one neutral raw row was enqueued with Wi-Fi/data
off, survived force-stop plus a 5,527 ms offline cold launch, then changed to
server-received after Wi-Fi returned. A second 5,122 ms online cold launch rendered
its marker exactly once. This does not claim delivery/read receipt or exact lost-ACK.

Earlier Web runner checkpoint: the reported demo-login mismatch came from a raw Flutter Web
launch without Staging defines, which falls back to Production config; the later
local server was also stopped. The runner now supports `web-device`, uses exact
Staging temporary defines and renders a visible environment banner only with the
Chat flag. Real Chrome rendered the complete login UI. Later checkpoints proved the
demo sign-in and two-client relay; no schema/Production/Training write ran here.

Earlier 2026-09-16 device checkpoint: Android build/update/startup VERIFIED, live C3 PARTIAL.
CPH2375 was authorized, then USB dropped and returned unauthorized. User must allow
debugging again. Staging APK build 143.2s; install -r success/no clear-data; cold
activity launch Status ok/9727ms, Home rendered. Chat separate DB exists, Library
DB + 3 JPEG preserved, startup error counters all 0. Friends/inbox/detail and
airplane-mode cold restart not exercised yet. Second user-requested confirmed/test-only
Auth account created and login verified; both accounts lack C1 profiles and mutual
accepted relation. Approval for test roles/relation pending; do not configure silently.

Later 2026-09-16: user approved accepted friendship only. Two directed test rows are
accepted and each owner JWT sees the counterpart via RLS. Both language profiles
remain unknown. Friends tab displays accepted IDs from the existing paged provider
in opt-in Staging; 14 widget tests pass.

The first live Friends view showed the expected network error state and exposed the
actual root cause: current Android `MainActivity` had lost the `network_status`
MethodChannel handler documented by the 2026-09-11 checkpoint, so both Chat and
Library gates failed closed. `MainActivity` now
answers from `ConnectivityManager`; `ACCESS_NETWORK_STATE` is declared and only an
INTERNET + VALIDATED active network is accepted. No dependency or DB change.

Post-fix exact-Staging APK build PASS/92.6s, migration dry-run upToDate/no apply;
`adb install -r` Success, cold launch Status ok/9281ms. On the signed-in CPH2375,
the Friends tab shows exactly one peer + accepted marker; no error/empty state.
Sanitized runtime counters for host/socket/PostgREST/Auth/Flutter/overflow/missing
plugin are all 0. Library/chat SQLite DBs and 3 local JPEG remain. Full suite is
492 pass/1 existing opt-in skip/0 failure; targeted Chat/Friends 21 pass and analyzer
clean. This does not replace the required second-client message/restart smoke.

Later 2026-09-16 user confirmation: primary `vi→en`, accepted test peer `en→vi`.
Exactly two C1 rows now exist on Staging with default `beginner`; Production and
Training were not touched. Android Settings loaded and displayed the primary pair,
then Chat mới showed one peer with no missing-language/runtime/fetch error. Selecting
it passed the real `open_direct_chat` RPC and opened empty detail after the local cache
commit. Backend aggregate: 1 conversation, 2 active members, 0 operational messages,
0 Gemini calls, 0 Training writes. No synthetic message was sent. Device log error
counters remain 0; both SQLite DBs and 3 local JPEG remain. This is one-client open
evidence only; bidirectional raw relay and offline restart are still pending.

## Scope / contract

- Only exact Staging `nxteaznowkfennxpqjmt` + `CHAT_RELAY_ENABLED=true` + signed-in.
  Default/Production does not enable operational relay or access C1/C2 chat tables.
- Bạn bè → Trò chuyện · Staging → inbox `/chat` → detail `/chat/:conversationId`.
- Lists/history are local SQLite reads, independent of foreground network refresh.
  Inbox labels peer by ID suffix; no fabricated names or profile API to render history.
- Chat mới explicitly loads accepted outgoing friend IDs. Server `open_direct_chat`
  checks two-way acceptance and both language profiles, returns canonical conversation;
  local commit must succeed before routing. Fresh conversation requires network.
- Existing active cached conversation composes offline when own cached profile is valid.
  Enqueue preserves raw text and is durable before clearing composer. Pending retries
  reuse original client key; blocked is retained, not automatically resubmitted.
- “Server đã nhận” is not a delivery/read receipt. UI currently displays raw text only.
- No Gemini/translation, correction, tagging, Training promotion/export. Legacy chatbot
  datasource unchanged; Library/AI DB untouched. C4/C5/C6 are separate milestones.
- Changing account removes old history and draft. Unknown language disables sending
  without fetching profile; configure it explicitly in Settings.
- Friends tab now lists accepted IDs in opt-in Staging; invitation/acceptance
  management and leaderboard remain out of scope. Picker does not create invitations
  or accept requests. Fresh list requires network; chat history remains cache-first.

## Local verification

```powershell
C:\fulter\flutter\bin\flutter.bat test --no-pub test/features/chat/operational_chat_screen_test.dart --reporter expanded
C:\fulter\flutter\bin\flutter.bat analyze --no-pub
```

14 screen widget tests pass; 21 combined provider + screen tests pass after the
native fix. Analyzer clean. FFI uses isolated SQLite, synthetic Auth and
HTTP/gateway fixtures, not real cloud clients. Includes network-free offline read/
enqueue, unknown/cache notification, account isolation, deep-link guard, statuses,
explicit scoped paged picker, canonical open and phone/wide/keyboard/Unicode cases,
and gated friends CTA without SDK/DB access when disabled. Completion waits use
expected state/deadline, with widget unmount before fixture resource disposal.

Latest full regression `flutter test --no-pub --reporter compact`: 495 pass,
1 existing opt-in skip, 0 failures, exit0; combined chat is 90. Latest analyzer
is clean. The targeted gateway/provider/coordinator run is 54 pass.

## Staging build / device runner

```powershell
# Build artifact only; this does NOT open a browser or verify live chat.
.\tool\run_staging_device_smoke.ps1 -FlutterCommand 'C:\fulter\flutter\bin\flutter.bat' -Target web-build -ChatRelayEnabled

# Interactive Web Staging; keep this terminal open while testing.
.\tool\run_staging_device_smoke.ps1 -FlutterCommand 'C:\fulter\flutter\bin\flutter.bat' -Target web-device -WebPort 3000 -ChatRelayEnabled

# Once Android is connected/authorized: replace DEVICE_ID with flutter devices ID.
.\tool\run_staging_device_smoke.ps1 -FlutterCommand 'C:\fulter\flutter\bin\flutter.bat' -Target android-device -DeviceId 'DEVICE_ID' -ChatRelayEnabled
```

Runner validates exact linked healthy Staging, reads public key into a temporary
define file, enables Library sync and chat. It only dry-runs migrations; no apply,
relink, Production write or committed secrets. Public client build key is not a
service key. Current Android/Web smoke verifies raw rows in both directions and
receiving render on both clients. Android offline pending/process restart/reconnect
single-render, exact lost-ACK idempotency, physical account switch and membership
revocation are verified. This is not a delivery/read receipt and does not implement
C4/C5.

Latest Web Staging compile PASS/exit0 (130.5s), `build/web`, both rollout flags ON.
Dry-run upToDate=true/no apply. Existing flutter_tts Wasm and Cupertino font warnings
remain. Real Chrome login, exact-environment banner and bidirectional raw relay render
PASS; offline app-shell cold start remains a separate unimplemented PWA gate.

## Live exit checklist — COMPLETE

Use two distinct Staging accounts, mutually accepted friends, with C1 profiles
VI→EN / EN→VI. Do not silently edit demo account relations or Production.

1. **VERIFIED:** A opened the canonical direct chat and both clients opened the chat.
2. **VERIFIED bidirectionally:** Web→Android and Android→Web rendered; after Android
   APK parity was restored, a fresh Web→Android message was user-confirmed again.
   Exact lost-ACK behavior still belongs to step 4.
3. **VERIFIED on Android 13:** A lost all network routes, sent in the cached chat,
   and the local row survived force-stop plus a 5,527 ms cold launch. Navigation back
   to the detail worked offline. No current-process sync failure was logged.
4. **VERIFIED cross-layer:** normal reconnect changed pending to server-received and
   rendered once. Client lost-response/restart test retries the same key and merges one
   canonical row; live Staging rejects the retry duplicate without a second row.
5. **VERIFIED on Android:** A→B→A passed with the expected opposite profiles and
   distinct owner scopes. After returning to A, its original detail/history/composer
   opened with Wi-Fi and mobile data disabled; no cross-account cache mixing occurred.
6. **VERIFIED cross-layer:** live Staging inactive member is denied/hidden and cleanup
   restores baseline; coordinator test hides cached history, blocks pending and rejects
   late old-session mutation. RLS remains authoritative.
7. Library regression: existing backed-up lessons/local images remain accessible
   offline. Web offline app-shell cold start is a separate unimplemented PWA gate.

Record actual client/platform, timestamps and safe aggregate counts in db_status.md
and chat_DB.md. Never substitute localhost WebSocket/mock/widget/build success for
two real authenticated clients or a real airplane-mode cold restart.
