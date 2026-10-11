param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [ValidateSet('All','Windows','Web')][string]$Target = 'All',
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (!$OutputDirectory) { $OutputDirectory = Join-Path (Split-Path $projectRoot -Parent) 'builds' }
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if ($outputRoot -eq $projectRoot -or $outputRoot.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose an output directory outside the source project so snapshots cannot absorb packaged builds.'
}
$version = & $Godot --version
if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^4\.7\.2\.stable') { throw 'Use the Godot 4.7.2 standard console executable with matching export templates.' }
& $Godot --headless --path $projectRoot --import
if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
$jobs = @()
if ($Target -in @('All','Windows')) { $jobs += @{Name='Windows Desktop'; Folder='windows'; File='JumpingSpiderSim.exe'} }
if ($Target -in @('All','Web')) { $jobs += @{Name='Web'; Folder='web'; File='index.html'} }
foreach ($job in $jobs) {
    $folder = Join-Path $outputRoot $job.Folder
    New-Item -ItemType Directory -Force $folder | Out-Null
    $destination = Join-Path $folder $job.File
    & $Godot --headless --path $projectRoot --export-release $job.Name $destination
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $destination)) { throw "Export failed: $($job.Name)" }
    Write-Output "Built $destination"
}
