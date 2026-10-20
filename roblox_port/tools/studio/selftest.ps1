<#
.SYNOPSIS
  Prints the live place's self-test (ROBLOX-104) as it runs in Roblox Studio, from Studio's own log files.

.DESCRIPTION
  The self-test (src/Client/SelfTest.luau) runs inside a Studio Play session of the live place when the Workspace attribute
  SelfTest is true, and prints every line to Output beginning with [SELFTEST]. Studio writes Output to a log file of its own per
  process, under %LOCALAPPDATA%\Roblox\logs, with a prefix (a timestamp, a thread id and [FLog::CreatorOutput] or the like) before
  each line. This script finds the newest log modified in the last few minutes that holds a "[SELFTEST] BEGIN", prints the lines
  of the latest run in it with the prefix stripped, follows the file as Studio writes it, and stops at the run's END line or the
  deadline, whichever comes first.

  How to run the self-test (docs/HANDOFF-roblox-world.md, "ROBLOX-104"):
    1. Open the live place (TheWindowsill.rbxlx) in Studio.
    2. In the command bar: workspace:SetAttribute("SelfTest", true)
    3. Press Play. Nothing else: the test begins a new life itself (the start menu's "Begin a new life").
    4. Run this script in PowerShell:  .\roblox_port\tools\studio\selftest.ps1   (or start it with -New before pressing Play)
    5. When it says END, stop the Play session. Clear the attribute before saving the place if it should not stay set:
       workspace:SetAttribute("SelfTest", nil)  (the test never runs outside Studio, whatever the attribute says).

  By default the latest run in the logs is printed (run the script during the Play session or after it). With -New, runs already in the
  logs when the script starts are ignored and it waits for the next one (start the script, then press Play).

  Exit code: 0 when the run ended with fail=0, 1 when it ended with failures, 2 when no END was seen before the deadline.

.PARAMETER Minutes
  Only logs modified within this many minutes are looked at (default 10).

.PARAMETER Timeout
  Seconds to wait for the END line (default 300; the run itself is about a minute and a half, plus streaming).

.PARAMETER LogDir
  Where Studio's logs are (default $env:LOCALAPPDATA\Roblox\logs).

.PARAMETER New
  Ignore the runs already in the logs when the script starts; wait for a new one.

.EXAMPLE
  .\roblox_port\tools\studio\selftest.ps1 -Timeout 400
#>
param(
    [int]$Minutes = 10,
    [int]$Timeout = 300,
    [string]$LogDir = (Join-Path $env:LOCALAPPDATA 'Roblox\logs'),
    [switch]$New
)

$ErrorActionPreference = 'Stop'
$marker = '[SELFTEST]'

# Reads a log Studio still has open (it writes with the file shared for reading).
function Read-Log([string]$path) {
    try {
        $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd() -split "`r?`n"
        } finally {
            $stream.Dispose()
        }
    } catch {
        return @()
    }
}

# The [SELFTEST] lines of the latest run in a log, with whatever comes before the marker stripped.
function Get-RunLines([string[]]$lines) {
    $run = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        $at = $line.IndexOf($marker)
        if ($at -lt 0) { continue }
        $text = $line.Substring($at)
        if ($text.StartsWith("$marker BEGIN")) { $run.Clear() }
        $run.Add($text)
    }
    return ,$run
}

# How many runs a log holds (its BEGIN lines).
function Get-BeginCount([string[]]$lines) {
    $n = 0
    foreach ($line in $lines) { if ($line.Contains("$marker BEGIN")) { $n++ } }
    return $n
}

if (-not (Test-Path -LiteralPath $LogDir)) {
    Write-Host "No Roblox log folder at $LogDir"
    exit 2
}

# With -New: the runs each log already holds, so only a later one is followed.
$before = @{}
if ($New) {
    foreach ($log in Get-ChildItem -LiteralPath $LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue) {
        $before[$log.FullName] = Get-BeginCount (Read-Log $log.FullName)
    }
}

$deadline = (Get-Date).AddSeconds($Timeout)
$printed = 0
$current = $null
Write-Host "Waiting for [SELFTEST] lines in $LogDir (logs from the last $Minutes minutes, up to $Timeout s)..."
while ((Get-Date) -lt $deadline) {
    $since = (Get-Date).AddMinutes(-$Minutes)
    $logs = Get-ChildItem -LiteralPath $LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $since } |
        Sort-Object LastWriteTime -Descending
    foreach ($log in $logs) {
        $lines = Read-Log $log.FullName
        if ($New -and $before.ContainsKey($log.FullName) -and (Get-BeginCount $lines) -le $before[$log.FullName]) { continue }
        $run = Get-RunLines $lines
        if ($run.Count -eq 0 -or -not $run[0].StartsWith("$marker BEGIN")) { continue }
        if ($current -ne $log.FullName) {
            if ($null -ne $current) { Write-Host "(a newer run in $($log.Name))" }
            $current = $log.FullName
            $printed = 0
            Write-Host "Log: $($log.FullName)"
        }
        for ($i = $printed; $i -lt $run.Count; $i++) { Write-Host $run[$i] }
        $printed = $run.Count
        $last = $run[$run.Count - 1]
        if ($last -match '^\[SELFTEST\] END pass=(\d+) fail=(\d+)') {
            if ([int]$Matches[2] -eq 0) { exit 0 } else { exit 1 }
        }
        break
    }
    Start-Sleep -Seconds 2
}
Write-Host "No END line before the deadline ($Timeout s)."
exit 2
