# P6 verification baseline - 2026-09-01

## Outcome

P6 test infrastructure and database/security verification are complete. The
stub load ladder and authenticated canary scans are not yet complete, so P6
must remain in progress.

No production promotion, real Gemini load test, commit, or push was performed.

## Source verification

- Added a local Gemini-compatible stub and a no-dependency load runner under
  `supabase/functions/gemini-vision-scan/p6/`.
- The runner supports `100% Free`, `100% Pro`, `99/1`, and `98/2` profiles at
  configurable rates up to `500 RPM`.
- The runner fails when success is below `99%`, HTTP `429` reaches `1%`, or a
  successful response crosses the expected tier/model pool.
- A hard safety gate requires `P6_CONFIRM_GEMINI_STUB=YES` before any load is
  sent.
- `GEMINI_API_BASE_URL` is optional and defaults to Google's official Gemini
  endpoint. It exists only to redirect local P6 traffic to the stub.
- No quota value from the old Free Tier is hard-coded.

Commands and results:

```text
deno check index.ts p6/gemini_stub.ts p6/load_test.ts
PASS

deno fmt --check p6/gemini_stub.ts p6/load_test.ts p6/p6_test.ts
PASS

deno test --allow-env
PASS: 72 passed, 0 failed

deno run --allow-env --allow-net p6/load_test.ts
EXPECTED REFUSAL: missing P6_CONFIRM_GEMINI_STUB=YES; zero load sent

git diff --check
PASS
```

The first sandboxed Deno test attempts panicked in Deno `2.9.5` because the
Windows named pipe was denied. The identical test command passed outside that
process sandbox; this was an environment failure, not a failed assertion.

## Remote Supabase evidence

- Production `gemini-vision-scan` remains version `35`, SHA prefix
  `19059f670e`; it is the old bundle.
- Canary `gemini-vision-scan-canary` remains version `16`, SHA prefix
  `c1a8a5cb`; it contains P5.
- Remote schema lint at warning level reported no schema errors.
- `subscriptions` grants authenticated users `SELECT` only; `service_role`
  retains write access.
- `ai_scan_requests` grants `SELECT`, `INSERT`, and `UPDATE` only to
  `service_role`; authenticated clients cannot write or read the ledger.
- The subscription entitlement index and AI Scan ledger/health indexes exist
  and show use in remote index statistics.
- Database advisors did not report a warning against the P1-P5 AI Scan tables.

Existing findings outside P6 scope remain: several older public RPCs use
`SECURITY DEFINER`, leaked-password protection is disabled, and older unrelated
tables have RLS performance/duplicate-policy advisories. P6 did not change or
suppress these findings.

## Real scan status

The owner reported one successful Pro scan using the demo account and one
successful Free scan using a newly created account after temporarily replacing
the Gemini key. This confirms the user-facing production path works for those
two accounts, but it does not verify the P5 canary path:

- Flutter's default endpoint is still `gemini-vision-scan` (production).
- Remote `ai_scan_requests` contains `0` rows after those scans.
- Ledger rows are retained even when cached result JSON expires.

Therefore authenticated canary routing, `model_used`, ledger telemetry, and
duplicate-call behavior remain unverified end to end.

## Remaining P6 work

1. Start Docker Desktop and local Supabase.
2. Run the stub profiles at `15 -> 50 -> 150 -> 500 RPM`, stopping at the first
   failed rung.
3. After every rung, record success/429/P95, `calls_per_scan`, duplicates, and
   Supabase CPU/RAM/connections.
4. Run one authenticated Free and one authenticated Pro request against the P5
   canary and verify ledger/tier/model values.
5. Defer real Gemini load until Tier 1 quota and budget alerts are available.
