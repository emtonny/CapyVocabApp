# Current State — 2026-09-12

- Branch `AI-scan`, HEAD `b742ea4`; ahead 0 / behind 0 against `origin/AI-scan`.
- Imported both incoming commits and preserved the existing documentation reorganization.
- Local uncommitted integration restores Vilao as the default API, retaining the new auth, entitlement, ledger, circuit breaker and Library contracts.
- Verification: Flutter analyzer clean; 390 tests passed + 1 opt-in live test skipped; 82 Deno tests passed; Web and Android debug builds passed.
- Fixed four Settings test failures caused by an opaque Container between ListTile and Material.
- Read-only client-project migration history matches all 21 local migrations. No migration, deployment or secret change was performed.
- Existing remote main/canary Edge Functions are ACTIVE (v41/v19). Live Vilao validation of the merged source is pending deployment.
- Original local changes are recoverable from stash `1af17176dbcdb752876bc6e2aeab69db0743d2db`.
- Details, commands, configuration precedence and remaining warnings: [sync report](docs/github-vilao-sync.md).
- Database/Library historical evidence and decisions: [db_status.md](db_status.md).
