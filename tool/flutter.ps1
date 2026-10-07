# Run the SAME project through a temporary ASCII path (no project copy).
# Works around Flutter 3.44.6 analyzer Unicode/root-directory path failures.
# Keep Flutter flags verbatim; advanced parameter binding consumes -d as -Debug.
$FlutterArguments = @($args)
$ErrorActionPreference = 'Stop'
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExecutable = if ($flutterCommand) { $flutterCommand.Source } else { 'D:\app\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterExecutable)) {
    throw 'Flutter not found. Add your Flutter SDK bin directory to PATH.'
}
$projectDirectory = Split-Path -Parent $PSScriptRoot
# App builds/runs need the same public Auth configuration on every invocation.
# Keep explicit configuration overrides available for other environments.
if ($FlutterArguments.Count -gt 0 -and $FlutterArguments[0] -in @('build', 'run')) {
    $explicitAuth = $FlutterArguments | Where-Object {
        $_ -match '^--dart-define-from-file($|=)' -or $_ -match 'SUPABASE_(URL|PUBLISHABLE_KEY)='
    }
    if (-not $explicitAuth) {
        $authConfigPath = Join-Path $projectDirectory 'config/supabase.local.json'
        if (-not (Test-Path -LiteralPath $authConfigPath)) {
            throw 'Missing config/supabase.local.json. Configure public Supabase URL/key before building or running the app.'
        }
        $authConfig = Get-Content -Raw -LiteralPath $authConfigPath | ConvertFrom-Json
        $authUri = $null
        if (-not [Uri]::TryCreate($authConfig.SUPABASE_URL, [UriKind]::Absolute, [ref]$authUri) -or
            $authUri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($authConfig.SUPABASE_PUBLISHABLE_KEY)) {
            throw 'Invalid public Supabase configuration. App build stopped to avoid shipping broken authentication.'
        }
        $FlutterArguments += "--dart-define-from-file=$authConfigPath"
        Write-Host 'Using local Supabase configuration for this app build/run.'
    }
}
# ASCII workspaces do not need a temporary drive. Using one unnecessarily
# leaves absolute Gradle/Dart cache paths pointing at a drive removed on exit.
if ($projectDirectory -notmatch '[^\x00-\x7F]') {
    Push-Location -LiteralPath $projectDirectory
    try {
        & $flutterExecutable @FlutterArguments
        $flutterExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    exit $flutterExitCode
}
$parentDirectory = Split-Path -Parent $projectDirectory
$projectName = Split-Path -Leaf $projectDirectory
$driveLetter = @('R','S','T','U','V','W','X','Y','Z') | Where-Object {
    -not (Test-Path -LiteralPath "${_}:\") -and -not (Get-PSDrive -Name $_ -ErrorAction SilentlyContinue)
} | Select-Object -First 1
if (-not $driveLetter) { throw 'No free temporary drive letter available.' }
& subst "${driveLetter}:" $parentDirectory
if ($LASTEXITCODE -ne 0) { throw 'Unable to create temporary ASCII drive alias.' }
$flutterExitCode = 1
Push-Location "${driveLetter}:\$projectName"
try {
    & $flutterExecutable @FlutterArguments
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
    & subst "${driveLetter}:" /D
}
exit $flutterExitCode
