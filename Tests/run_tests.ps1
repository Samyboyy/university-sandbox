<#
.SYNOPSIS
    University Sandbox - headless test runner (Windows).

.DESCRIPTION
    Runs Tests/run_tests.gd with Godot 3.6.2 while redirecting all Godot user data
    (APPDATA, LOCALAPPDATA, TEMP, XDG_* paths) into a new temporary folder named
    university_sandbox_tests.<id>. Your normal %APPDATA%\university_sandbox and
    %APPDATA%\Godot\app_userdata\BDCC folders are never used.

    The folder is deleted after a passing run (unless -Keep is given) and preserved
    after a failing run.

    Exit codes: 0 = pass, 1 = test failure, 2 = setup error.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Tests\run_tests.ps1 -Godot "C:\Tools\Godot_v3.6.2-stable_win64.exe"

.EXAMPLE
    $env:GODOT_BIN = "C:\Tools\Godot_v3.6.2-stable_win64.exe"; .\Tests\run_tests.ps1 -Keep
#>
[CmdletBinding()]
param(
    [string]$Godot = $env:GODOT_BIN,
    [switch]$Keep,
    [int]$TimeoutSeconds = 600
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$ExpectedVersionPrefix = '3.6.2.'
$RootPrefix = 'university_sandbox_tests.'
$MarkerName = '.university_sandbox_test_root'

function Stop-WithSetupError([string]$Message) {
    Write-Host "SETUP ERROR: $Message" -ForegroundColor Red
    exit 2
}

$RepoDir = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $RepoDir 'project.godot') -PathType Leaf)) {
    Stop-WithSetupError "project.godot not found in $RepoDir"
}
if (-not (Test-Path -LiteralPath (Join-Path $RepoDir 'Tests\run_tests.gd') -PathType Leaf)) {
    Stop-WithSetupError "Tests\run_tests.gd not found in $RepoDir"
}
if ([string]::IsNullOrWhiteSpace($Godot)) {
    Stop-WithSetupError 'No Godot executable given. Use -Godot PATH or set $env:GODOT_BIN.'
}
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    Stop-WithSetupError "Godot executable not found: $Godot"
}
$Godot = (Resolve-Path -LiteralPath $Godot).ProviderPath

# PortableModeDetector redirects user data next to the executable if this folder exists.
$PortableDir = Join-Path (Split-Path -Parent $Godot) 'UniversitySandboxData'
if (Test-Path -LiteralPath $PortableDir) {
    Stop-WithSetupError "$PortableDir exists, so portable mode would redirect user data. Use a Godot executable in a folder without it."
}

$TempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$TestRoot = Join-Path $TempBase ($RootPrefix + [guid]::NewGuid().ToString('N').Substring(0, 12))
New-Item -ItemType Directory -Path $TestRoot | Out-Null
New-Item -ItemType File -Path (Join-Path $TestRoot $MarkerName) | Out-Null
foreach ($sub in 'appdata', 'localappdata', 'temp', 'home') {
    New-Item -ItemType Directory -Path (Join-Path $TestRoot $sub) | Out-Null
}
$AppDataDir = Join-Path $TestRoot 'appdata'
$ExpectedUserDir = Join-Path $AppDataDir 'university_sandbox'
$OutputLog = Join-Path $TestRoot 'harness_output.log'
$GodotLog = Join-Path $ExpectedUserDir 'logs\godot.log'

function Remove-TestRootSafely {
    # Only ever removes the exact folder this script created.
    if ([string]::IsNullOrWhiteSpace($TestRoot)) { return $false }
    if (-not (Test-Path -LiteralPath $TestRoot -PathType Container)) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $TestRoot $MarkerName) -PathType Leaf)) { return $false }
    $leaf = Split-Path -Leaf $TestRoot
    if ($leaf -notmatch '^university_sandbox_tests\.[0-9a-f]{12}$') { return $false }
    $parent = [System.IO.Path]::GetFullPath((Split-Path -Parent $TestRoot)).TrimEnd('\')
    if ($parent -ne $TempBase) { return $false }
    Remove-Item -LiteralPath $TestRoot -Recurse -Force
    return $true
}

function Invoke-IsolatedGodot([string]$Arguments, [int]$TimeoutMs) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Godot
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $RepoDir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $vars = $psi.EnvironmentVariables
    $vars['APPDATA'] = $AppDataDir
    $vars['LOCALAPPDATA'] = (Join-Path $TestRoot 'localappdata')
    $vars['TEMP'] = (Join-Path $TestRoot 'temp')
    $vars['TMP'] = (Join-Path $TestRoot 'temp')
    $vars['HOME'] = (Join-Path $TestRoot 'home')
    $vars['XDG_DATA_HOME'] = $AppDataDir
    $vars['XDG_CONFIG_HOME'] = $AppDataDir
    $vars['XDG_CACHE_HOME'] = (Join-Path $TestRoot 'temp')
    $vars['US_TEST_ROOT'] = $TestRoot

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    if (-not $process.WaitForExit($TimeoutMs)) {
        $timedOut = $true
        try { $process.Kill() } catch { }
        $null = $process.WaitForExit(10000)
    }
    $process.WaitForExit()
    return [pscustomobject]@{
        ExitCode = $(if ($timedOut) { 124 } else { $process.ExitCode })
        TimedOut = $timedOut
        Output   = ($stdoutTask.Result + "`n" + $stderrTask.Result)
    }
}

Write-Host 'University Sandbox test runner'
Write-Host "  project:   $RepoDir"
Write-Host "  godot:     $Godot"
Write-Host "  test root: $TestRoot"

$versionRun = Invoke-IsolatedGodot '--version' 60000
$versionLines = @($versionRun.Output -split "`r?`n" | Where-Object { $_.Trim() -ne '' })
$godotVersion = if ($versionLines.Count -gt 0) { $versionLines[-1].Trim() } else { '' }
if ($godotVersion -eq '') {
    Write-Host '  version:   could not be read (Windows GUI builds may not print it); please make sure this is Godot 3.6.2' -ForegroundColor Yellow
} elseif (-not $godotVersion.StartsWith($ExpectedVersionPrefix)) {
    Stop-WithSetupError "expected Godot ${ExpectedVersionPrefix}x, got '$godotVersion'. Test folder preserved: $TestRoot"
} else {
    Write-Host "  version:   $godotVersion"
}
Write-Host ''

$quotedRepo = '"' + $RepoDir + '"'
$run = Invoke-IsolatedGodot "--path $quotedRepo --no-window -s res://Tests/run_tests.gd" ($TimeoutSeconds * 1000)

# Windows GUI builds may not write to redirected stdout, so fall back to Godot's own log file.
$output = $run.Output
if ($output -notmatch 'HARNESS RESULT:' -and (Test-Path -LiteralPath $GodotLog -PathType Leaf)) {
    $output = Get-Content -LiteralPath $GodotLog -Raw
}
Set-Content -LiteralPath $OutputLog -Value $output -Encoding UTF8
$lines = @($output -split "`r?`n")

$lines | Where-Object { $_ -match '^(HARNESS|==|  \[|         (expected|observed)|====)' } | ForEach-Object { Write-Host $_ }

$scriptErrors = @($lines | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error' }).Count
$networkErrors = @($lines | Where-Object { $_ -match "TLS handshake|Couldn.t get data from github|Couldn.t get the latest release" }).Count
$dummyErrors = 0
$otherErrors = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch '^ERROR: ') { continue }
    $at = ''
    if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\s+at: ') { $at = $lines[$i + 1].Trim() }
    if ($lines[$i] -match 'NULL RID' -or $at -match 'rasterizer_dummy') { $dummyErrors++ }
    elseif ($lines[$i] -match 'TLS handshake') { }
    else { $otherErrors.Add(($lines[$i] + '  ' + $at).Trim()) }
}

Write-Host ''
Write-Host 'Runner checks'
Write-Host "  godot exit code:              $($run.ExitCode)"
Write-Host "  script/parse errors:          $scriptErrors"
Write-Host "  startup network errors:       $networkErrors"
Write-Host "  dummy-renderer messages:      $dummyErrors (ignored)"
Write-Host "  other engine ERROR lines:     $($otherErrors.Count) (shown below, not treated as failures)"
$otherErrors | Group-Object | Select-Object -First 20 | ForEach-Object { Write-Host ("    {0,5} {1}" -f $_.Count, $_.Name) }
if ($scriptErrors -gt 0) {
    Write-Host '  script errors:'
    $lines | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error' } | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
}

$failReasons = New-Object System.Collections.Generic.List[string]
if ($run.ExitCode -ne 0) {
    if ($run.TimedOut) { $failReasons.Add("Godot hit the $TimeoutSeconds s time limit") }
    else { $failReasons.Add("Godot exited with $($run.ExitCode)") }
}
if (-not ($lines -contains 'HARNESS RESULT: PASS')) { $failReasons.Add('harness did not report PASS') }
if ($scriptErrors -gt 0) { $failReasons.Add("$scriptErrors script/parse error line(s)") }
if ($networkErrors -gt 0) { $failReasons.Add("$networkErrors startup network line(s)") }
if (-not (Test-Path -LiteralPath $ExpectedUserDir -PathType Container)) {
    $failReasons.Add("expected isolated user folder was not created: $ExpectedUserDir")
}

Write-Host ''
if ($failReasons.Count -eq 0) {
    Write-Host 'OVERALL: PASS' -ForegroundColor Green
    if ($Keep) {
        Write-Host "Test folder kept (-Keep): $TestRoot"
    } elseif (Remove-TestRootSafely) {
        Write-Host "Test folder removed: $TestRoot"
    } else {
        Write-Host "WARNING: test folder was not removed because a safety check failed: $TestRoot" -ForegroundColor Yellow
    }
    exit 0
}

Write-Host 'OVERALL: FAIL' -ForegroundColor Red
foreach ($reason in $failReasons) { Write-Host "  - $reason" }
Write-Host "Test folder preserved for inspection: $TestRoot"
Write-Host "  full output:  $OutputLog"
Write-Host "  godot log:    $GodotLog"
exit 1
