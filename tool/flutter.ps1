# Run the SAME project through a temporary ASCII path (no project copy).
# Works around Flutter 3.44.6 analyzer Unicode/root-directory path failures.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$FlutterArguments)
$ErrorActionPreference = 'Stop'
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterExecutable = if ($flutterCommand) { $flutterCommand.Source } else { 'D:\app\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterExecutable)) {
    throw 'Flutter not found. Add your Flutter SDK bin directory to PATH.'
}
$projectDirectory = Split-Path -Parent $PSScriptRoot
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
