# P0 Dirty Worktree Baseline

- Captured at: 2026-08-27 (Asia/Bangkok)
- Purpose: preserve all user changes before P1 implementation.
- Git branch: `AI-scan`
- Git HEAD: `318249f77958f46e1b8b01b518a2ba6511932a3c`
- Git remote: `origin https://github.com/emtonny/CapyVocabApp.git`
- Tracked patch: `tracked_changes.patch`
- Untracked patch: `untracked_files.patch`
- Status and SHA-256 manifest: `worktree_manifest.txt`
- Restore is intentionally manual; no stash, reset, checkout, commit, or destructive operation was performed.
- Files created under this baseline directory are implementation artifacts and are not part of the pre-P1 snapshot.
- P1 implementation and rollout evidence: `P1_VERIFICATION.md`.

## Snapshot integrity

| Artifact | Lines | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `tracked_changes.patch` | 2,216 | 85,727 | `ca9f49853ad6ab0f8dd7b9b1e58a3528a1485c839fbb49dd07b6f5172e3f6ef1` |
| `untracked_files.patch` | 3,176 | 115,140 | `87b5bdd836867316b5ac64ac570d644c2f04f3b679a14e845241ff7a98225078` |
| `worktree_manifest.txt` | 55 | 4,558 | `9d066c0b9616e164eb393953cdf79b38f2ff9c3cfbae4663c27e6af1fa209c02` |

## Pre-P1 verification

- Flutter `3.41.6`, Dart `3.11.4`.
- Deno `2.9.5`, TypeScript `6.0.3`.
- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 185 tests.
- `deno test --allow-env`: passed, 33 tests.
- `deno check index.ts`: passed.
- `deno lint`: failed with 7 pre-existing findings:
  - 2 `prefer-const` findings in `gemini_client_test.ts`.
  - 1 `no-import-prefix` finding in `index.ts`.
  - 4 `no-unused-vars` findings in `index.ts`.
- Supabase CLI: unavailable in `PATH`; remote inspection used the configured Supabase connection instead.

## Remote baseline

- Supabase project: `CapyVocabApp` (`vmxonxqxrlkssdzsucrg`).
- Production `gemini-vision-scan`: version 33, active, platform `verify_jwt=false`, SHA-256 `fe067d4571ee6f197f20d8c3736e87425081c6ffc88d6f31805b2748380bf3dc`.
- Canary `gemini-vision-scan-canary`: version 11, active, platform `verify_jwt=true`, SHA-256 `dee62ce6e8070b2e2e1ea0b0ea1fbbde1a684fe6c3deb0fe38f951af2c45e011`.

## Manual restore procedure

Use a clean checkout at the recorded HEAD, verify the three SHA-256 values above, then apply `tracked_changes.patch` followed by `untracked_files.patch` with `git apply --binary`. Do not apply these patches on top of the current dirty worktree. The manifest provides per-file hashes for a final integrity check.
