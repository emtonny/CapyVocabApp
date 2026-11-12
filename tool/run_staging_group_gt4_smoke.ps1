#requires -Version 7.0
param(
    [string]$ExpectedProjectName = "emtonny's Project",
    [string]$PostgresBin = 'C:\Program Files\PostgreSQL\18\bin'
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'run_staging_group_gt2_smoke.ps1') `
    -ExpectedProjectName $ExpectedProjectName `
    -PostgresBin $PostgresBin `
    -IncludeGt3Chat `
    -IncludeGt4Management
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
