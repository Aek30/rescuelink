param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$fixturePath = Join-Path $projectRoot 'config/test-account.local.json'

Write-Host 'Use an existing confirmed Supabase test account for this project.'
Write-Host 'This updates the ignored local test credentials, then runs the real cloud test.'
Write-Host 'The test uploads synthetic text, SOS and an image, restores them on a second'
Write-Host 'local installation, then removes its fixtures (chat rows become tombstones).'
$testEmail = (Read-Host 'Test account email').Trim()
$testPassword = Read-Host 'Test account password (hidden)' -AsSecureString
if ([string]::IsNullOrWhiteSpace($testEmail) -or $testPassword.Length -eq 0) {
    throw 'Email and password are required.'
}

$credential = New-Object System.Net.NetworkCredential('', $testPassword)
try {
    $fixtureJson = @{
        email = $testEmail
        password = $credential.Password
    } | ConvertTo-Json
    [System.IO.File]::WriteAllText(
        $fixturePath, $fixtureJson, (New-Object System.Text.UTF8Encoding($false))
    )
} finally {
    $fixtureJson = $null
    $credential = $null
    $testPassword.Dispose()
}

Push-Location $projectRoot
try {
    & flutter test test/chat_cross_device_live_test.dart --dart-define=RUN_LIVE_CHAT=true --reporter expanded
    if ($LASTEXITCODE -ne 0) {
        throw 'Live cloud verification failed. See the test result above.'
    }
    Write-Host 'PASS: real Supabase upload and restoration were verified.'
} finally {
    Pop-Location
}
