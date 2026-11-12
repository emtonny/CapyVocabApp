param([Parameter(Mandatory)][string]$SupabaseCli)

# All fixtures and functions live in random schemas and roll back together.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectRef = 'nxteaznowkfennxpqjmt'
$prefix = 'coin_rank_test_' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$temporarySql = Join-Path ([IO.Path]::GetTempPath()) "$prefix.sql"
$bootstrap = Get-Content (Join-Path $repoRoot 'supabase/tests/home_h2a_bootstrap.sql') -Raw
$bootstrap = [regex]::Replace($bootstrap, '(?m)^CREATE ROLE .*;\s*', '')
$bootstrap = $bootstrap.Replace('CREATE PUBLICATION supabase_realtime;', '')
$migration = Get-Content (Join-Path $repoRoot 'supabase/migrations/20261008173000_rank_wallet_and_earned_coins.sql') -Raw
$tests = Get-Content (Join-Path $repoRoot 'supabase/tests/home_wallet_earned_leaderboard_security.sql') -Raw
$ledger = @'
CREATE TABLE public.yuzu_reward_ledger (
 user_id UUID NOT NULL, mission_date DATE NOT NULL,
 wallet_yuzu INTEGER NOT NULL, weekly_yuzu INTEGER NOT NULL,
 created_at TIMESTAMPTZ NOT NULL
);
'@
$sql = "CREATE SCHEMA public;`n" + $bootstrap + $ledger + $migration + $tests
foreach ($schema in @('public', 'private', 'auth')) {
    $sql = [regex]::Replace($sql, "\b$schema\b", "${prefix}_${schema}")
}
$sql = "BEGIN;`nSET LOCAL statement_timeout = '20s';`n" + $sql +
    "`nSELECT 'PASS: 13 wallet/earned ranking assertions' AS result;`nROLLBACK;"
try {
    [IO.File]::WriteAllText($temporarySql, $sql, [Text.UTF8Encoding]::new($false))
    & $SupabaseCli db query --linked --project-ref $projectRef --file $temporarySql --output json
    if ($LASTEXITCODE -ne 0) { throw 'Isolated leaderboard assertions failed.' }
    $check = "SELECT count(*)=0 AS rolled_back FROM pg_namespace WHERE nspname LIKE '${prefix}%';"
    $result = (& $SupabaseCli db query --linked --project-ref $projectRef $check --output json | Out-String) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $result.rows.Count -ne 1 -or $result.rows[0].rolled_back -ne $true) {
        throw 'Unable to verify fixture rollback.'
    }
    Write-Output 'Verified: 13 SQL assertions; synthetic schemas rolled back.'
} finally {
    Remove-Item -LiteralPath $temporarySql -ErrorAction SilentlyContinue
}
