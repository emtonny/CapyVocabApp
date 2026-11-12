# GitHub integration checkpoint — 2026-11-12

## Scope and history

- Target repository: `emtonny/CapyVocabApp` (`origin`).
- Integration branch: `integration/app-sync-20261112`; Draft PR base: `interface`.
- Starting HEAD: `d03c80e`; preserve the already-resolved pending merge from
  `origin/chat` (`4596ad4`) as a merge parent. The original `interface` ref stays
  at its starting commit.
- Package existing Auth, Friends, Settings, Chat, Groups, Home, Library, photo
  games, assets, backend migration sources, regression tests and documentation.
- Keep the integrated source in one coherent merge commit: shared router,
  persistence and application runtime changes depend on the combined features.
- Exclude local preview/devlog artifacts, Python caches and 26 local skill-file
  deletions. Those deletions remain in the working tree. No local files are deleted.
- No migration application, function deployment, release or remote data write is
  part of this checkpoint.

## Verification

| Command/check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --reporter expanded` | 868 passed; one live opt-in skip |
| `deno test --config supabase/functions/chat-translation-worker/deno.json --node-modules-dir=auto --allow-env supabase/functions/chat-translation-worker` | 52 passed |
| `deno test --config supabase/functions/gemini-vision-scan/deno.json --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan` | 80 passed |
| `flutter build web --no-pub` | Passed, JavaScript build |
| `flutter build apk --debug --no-pub` | Passed |
| `dart format --output=none --set-exit-if-changed` on 215 changed existing Dart files, in batches | Passed after formatting five files |
| UTF-8 PowerShell parser check on 29 changed scripts | Zero syntax errors |
| High-confidence credential-pattern and privileged JWT scan | No matches in intended source files; not a full security audit |

The initial full Flutter run reproduced three previously documented failures:
Settings expected the retired person icon, and the button/navigation goldens
still showed vertical shadows. The shared avatar already uses a neutral painted
silhouette, as its own tests require; the Settings regression now checks that
fallback and continues to reject demo images. Reviewed master/test images
confirmed both golden differences came from the existing diagonal button-shadow
change. Updated only those two baselines, then reran the full suite without
`--update-goldens`. Runtime behavior was preserved.

Removed an extra EOF blank line in the existing change-feed migration draft;
its SQL behavior is unchanged. Added artifact/cache ignore rules. Local logs
and a copy of the pre-checkpoint Git index/merge metadata are under the ignored
`.tmp/github-sync-20261112/` directory.

## Remaining acceptance

- Native PostgreSQL and PowerShell 7 are absent. SQL security/concurrency suites
  and scripts requiring PowerShell 7 have not been executed; parsing is not an
  operational smoke test.
- Live device/backend acceptance remains pending, including account changes,
  offline/reconnect, groups/realtime and migration-history compatibility.
- No iOS build on this Windows host.
- Web reports existing Wasm compatibility and missing CupertinoIcons warnings.
  Android reports existing Kotlin/plugin and SDK XML compatibility warnings.
- Keep the PR in draft until backend/device acceptance is complete. Historical
  upstream deployment claims in other documents are not fresh verification of
  this integrated branch.
