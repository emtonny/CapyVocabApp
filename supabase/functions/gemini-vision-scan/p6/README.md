# P6 AI Scan load harness

This harness load-tests the Supabase Edge path without consuming Gemini RPD.
It has no third-party dependency and refuses to start unless the operator
explicitly confirms that Gemini traffic points to the included stub.

## Local setup

1. Start Docker Desktop and the local Supabase stack.
2. Start the stub:

   ```powershell
   deno run --allow-env --allow-net supabase/functions/gemini-vision-scan/p6/gemini_stub.ts
   ```

3. Serve the Edge Function with these additional local-only variables:

   ```text
   GEMINI_API_BASE_URL=http://host.docker.internal:8787/v1beta/models
   GEMINI_API_KEY=p6-local-stub-only
   ```

4. Create one local Free user and one local Pro user, then put their JWTs in
   `P6_FREE_JWT` and `P6_PRO_JWT`. Do not commit tokens or `.env` files.

## Run profiles

Set `P6_TARGET_URL`, `P6_PROFILE`, `P6_RPM`, `P6_DURATION_SECONDS`, the required
JWTs, and `P6_CONFIRM_GEMINI_STUB=YES`, then run:

```powershell
deno run --allow-env --allow-net supabase/functions/gemini-vision-scan/p6/load_test.ts
```

Profiles are `free`, `pro`, `free99-pro1`, and `free98-pro2`. Run each profile
at `15`, `50`, `150`, then `500` RPM. Stop at the first failed rung. The runner
fails when success is below 99%, 429 reaches 1%, or tier/model routing crosses.
Mixed runs must contain at least `100` requests for `99/1` and `50` requests for
`98/2`; the runner rejects smaller samples instead of reporting a misleading
profile.

After each rung, query `ai_scan_requests` to calculate `calls_per_scan`, confirm
duplicate calls are zero, and capture Supabase CPU/RAM/connections. Do not run
these profiles against a real Gemini key; real end-to-end load remains blocked
until Tier 1 quota and budget alerts are available.
