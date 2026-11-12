# Daily flame check-in — 2026-10-08

The Home “Thắp lửa” button records one streak day through
`public.light_streak_flame()`, rather than launching a lesson or capture.
The confirmed response updates the displayed count and owner-scoped Home cache.
Loading disables duplicate in-flight taps; failures keep the previous count
and allow retry. No coin or leaderboard reward is granted.

The server chooses today's date in the owner's account timezone, falling back
to `Asia/Ho_Chi_Minh` for legacy accounts without timezone settings (confirmed
by the user). Manual flame
days and existing on-time lesson completion days share one calendar: a date
counts once, including when a lesson was completed before tapping the flame.
Consecutive dates extend the streak; a gap restarts it at one. A user-row lock
serializes check-ins with reward settlement. Clients cannot supply a date,
owner, or count to the RPC.

On 2026-10-08 the configured app backend (`vmxonxqxrlkssdzsucrg`) returned
`PGRST202`: the RPC was absent. It also lacks the lesson calendar and account
timezone column required by the original migration. The migration now supports
that legacy schema directly, using manual dates alone when no lesson calendar
exists. A first recorded day starts at one; subsequent consecutive days extend
the streak. The client distinguishes a missing RPC from connectivity failures.

`tool/test_daily_flame_management.ps1 -SupabaseCli <installed-cli-path>` validated
13 SQL assertions in isolated synthetic schemas on Staging through the
Management API, including lesson/day deduplication, legacy schema, missing
settings, owner isolation and Vietnam date boundaries. The transaction rolled
back and a namespace query confirmed cleanup. No PostgreSQL installation was
needed; Docker Desktop could not start. The broader 74-check native Home harness
remains unrun.

The migration was applied alone, transactionally, to the configured app backend
and recorded as `20261008130000` in migration history. Post-deployment checks
confirmed the function, authenticated execute grant, blocked anonymous access
and history RLS. The REST endpoint no longer returns `PGRST202`; its unauthenticated
request returns the expected `401/42501`. Flutter: 24 targeted tests pass and
the changed screen/test analyze cleanly. A signed-in BlueStacks tap remains
unverified. Staging's public schema has not been migrated.

If lesson/reward migrations are subsequently installed on this legacy backend,
reconcile `streak_activity_days` and the two private streak functions with this
migration: the older lesson migration definitions do not include manual dates.

Daily task actions retain their existing capture, lesson, and replay behavior.
