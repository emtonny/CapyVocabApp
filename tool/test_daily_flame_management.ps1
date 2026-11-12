param(
    [Parameter(Mandatory)][string]$SupabaseCli,
    [string]$ProjectRef = 'nxteaznowkfennxpqjmt'
)

# Verify synthetic schemas only; the outer transaction always rolls back.
$ErrorActionPreference = 'Stop'
if ($ProjectRef -ne 'nxteaznowkfennxpqjmt') {
    throw 'This regression harness is restricted to Staging.'
}
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$prefix = 'flame_test_' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$temporarySql = Join-Path ([IO.Path]::GetTempPath()) "$prefix.sql"
$bootstrap = Get-Content (Join-Path $repoRoot 'supabase/tests/home_h2a_bootstrap.sql') -Raw
$bootstrap = [regex]::Replace($bootstrap, '(?m)^CREATE ROLE .*;\s*', '')
$bootstrap = $bootstrap.Replace('CREATE PUBLICATION supabase_realtime;', '')
$bootstrap = "CREATE SCHEMA public;`n" + $bootstrap
$migration = Get-Content (Join-Path $repoRoot 'supabase/migrations/20261008130000_add_daily_flame_checkin.sql') -Raw
$tests = Get-Content (Join-Path $repoRoot 'supabase/tests/home_daily_flame_security.sql') -Raw
$tests = [regex]::Replace($tests, '(?m)^BEGIN;\s*|^ROLLBACK;\s*', '')
$variables = @{}
foreach ($match in [regex]::Matches($tests, '(?m)^\\set (\w+) (.+)$')) {
    $variables[$match.Groups[1].Value] = $match.Groups[2].Value.Trim()
}
$tests = [regex]::Replace($tests, '(?m)^\\set .+\r?\n', '')
foreach ($key in $variables.Keys) { $tests = $tests.Replace(":'$key'", $variables[$key]) }

function Convert-IsolatedSql([string]$Sql, [string]$Suffix) {
    foreach ($schema in @('public', 'private', 'auth')) {
        $Sql = [regex]::Replace($Sql, "\b$schema\b", "${prefix}_${Suffix}_${schema}")
    }
    return $Sql
}

$calendarSetup = @'
ALTER TABLE public.user_settings ADD COLUMN time_zone TEXT;
CREATE TABLE public.lesson_streak_days(user_id UUID, mission_date DATE);
CREATE TABLE public.yuzu_reward_ledger(user_id UUID);
'@
$lessonTest = @'
INSERT INTO public.lesson_streak_days VALUES
('10000000-0000-4000-8000-000000000001', (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::DATE);
SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
SET ROLE authenticated;
SELECT public.h2a_assert((SELECT streak_days = 1 AND NOT incremented FROM public.light_streak_flame()),
'lesson and flame share one calendar day');
RESET ROLE;
'@
$legacyTests = @'
SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', false);
SET ROLE authenticated;
SELECT public.h2a_assert((SELECT streak_days = 1 AND incremented FROM public.light_streak_flame()),
'legacy schema without lesson calendar or timezone supports flame');
SELECT public.h2a_assert((SELECT streak_days = 1 AND NOT incremented FROM public.light_streak_flame()),
'legacy duplicate tap counts once');
SELECT public.h2a_assert(EXISTS (SELECT 1 FROM public.manual_streak_days
WHERE mission_date = (statement_timestamp() AT TIME ZONE 'Asia/Ho_Chi_Minh')::DATE),
'legacy account date uses Vietnam timezone');
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
DELETE FROM public.user_settings WHERE user_id = '10000000-0000-4000-8000-000000000002';
SET ROLE authenticated;
SELECT public.h2a_assert((SELECT streak_days = 1 AND incremented FROM public.light_streak_flame()),
'legacy account without settings supports flame');
RESET ROLE;
'@
$sql = "BEGIN;`nSET LOCAL statement_timeout = '20s';`n"
$sql += Convert-IsolatedSql ($bootstrap + $calendarSetup + $migration + $tests + $lessonTest) 'calendar'
$sql += Convert-IsolatedSql ($bootstrap + $migration + $legacyTests) 'legacy'
$sql += "`nSELECT 'PASS: 13 daily flame assertions, synthetic schemas only' AS result;`nROLLBACK;"
try {
    [IO.File]::WriteAllText($temporarySql, $sql, [Text.UTF8Encoding]::new($false))
    & $SupabaseCli db query --linked --project-ref $ProjectRef --file $temporarySql --output json
    if ($LASTEXITCODE -ne 0) { throw 'Isolated daily flame SQL regression failed.' }
    $check = "SELECT count(*) = 0 AS rolled_back FROM pg_namespace WHERE nspname LIKE '${prefix}%';"
    $rollbackJson = (& $SupabaseCli db query --linked --project-ref $ProjectRef $check --output json | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify test schema rollback.' }
    $rollback = ConvertFrom-Json $rollbackJson
    if ($rollback.rows.Count -ne 1 -or $rollback.rows[0].rolled_back -ne $true) {
        throw 'Synthetic test schemas were not rolled back.'
    }
    Write-Output 'Verified: 13 SQL assertions; synthetic schemas rolled back.'
}
finally {
    Remove-Item -LiteralPath $temporarySql -ErrorAction SilentlyContinue
}
