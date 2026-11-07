# GUNFARE_UPDATE_SCRIPT_WINDOWS
# Wait until the game stops. Replace the files. Start the game again.
# If a step fails, put the old files back and start the old game.
# Moved is "1" when the game ran from a temporary folder. Then InstallDir is a
# new permanent folder.
param(
    [Parameter(Mandatory = $true)][int]$WaitPid,
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$ExeName,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$Moved = "0"
)

$ErrorActionPreference = "Stop"
$stage = $null
$backup = $null
$movedItems = New-Object System.Collections.ArrayList
$placed = New-Object System.Collections.ArrayList
$detailPath = $LogPath + ".details"

function Write-Detail($text) {
    try {
        $line = (Get-Date).ToString("s") + " " + $text + [Environment]::NewLine
        [System.IO.File]::AppendAllText($detailPath, $line)
    } catch { }
}

function Write-UpdateLog($text) {
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($LogPath, $text, $utf8)
    Write-Detail $text
}

function Invoke-Retry([scriptblock]$Action, [string]$What) {
    $last = $null
    for ($i = 0; $i -lt 60; $i++) {
        try {
            & $Action
            return
        } catch {
            $last = $_
            Start-Sleep -Milliseconds 500
        }
    }
    throw ($What + " failed. " + $last.Exception.Message)
}

function Test-FileFree([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $true
    }
    try {
        $stream = [System.IO.File]::Open($Path, "Open", "ReadWrite", "None")
        $stream.Close()
        return $true
    } catch {
        return $false
    }
}

function Get-GameProcesses {
    $root = [System.IO.Path]::GetFullPath($InstallDir).TrimEnd([char]92, [char]47) + [System.IO.Path]::DirectorySeparatorChar
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $path = $null
        try { $path = $_.Path } catch { }
        $path -and $path.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
    }
}

function Start-Game {
    if ($env:GUNFARE_UPDATE_NO_START -eq "1") {
        return
    }
    $exe = Join-Path $InstallDir $ExeName
    if (Test-Path -LiteralPath $exe) {
        try { Start-Process -FilePath $exe -WorkingDirectory $InstallDir } catch { Write-Detail ("Start failed. " + $_.Exception.Message) }
    }
}

function Restore-OldFiles {
    for ($i = $placed.Count - 1; $i -ge 0; $i--) {
        $target = $placed[$i]
        try { Remove-Item -LiteralPath $target -Recurse -Force } catch { Write-Detail ("Remove failed. " + $target) }
    }
    for ($i = $movedItems.Count - 1; $i -ge 0; $i--) {
        $pair = $movedItems[$i]
        try {
            Invoke-Retry { Move-Item -LiteralPath $pair[1] -Destination $pair[0] -Force } "Restore"
        } catch {
            Write-Detail ("Restore failed. " + $pair[0])
        }
    }
}

try {
    Write-Detail ("Start. Folder " + $InstallDir)
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $deadline = (Get-Date).AddMinutes(2)
    while (Get-Process -Id $WaitPid -ErrorAction SilentlyContinue) {
        if ((Get-Date) -gt $deadline) {
            throw "The game did not close in 2 minutes."
        }
        Start-Sleep -Milliseconds 400
    }
    $deadline = (Get-Date).AddMinutes(1)
    while (@(Get-GameProcesses).Count -gt 0) {
        if ((Get-Date) -gt $deadline) {
            throw "Another GunFare window is open. Close all GunFare windows and try again."
        }
        Start-Sleep -Milliseconds 500
    }
    $exePath = Join-Path $InstallDir $ExeName
    $deadline = (Get-Date).AddMinutes(1)
    while (-not (Test-FileFree $exePath)) {
        if ((Get-Date) -gt $deadline) {
            throw "Another program uses $ExeName. Close that program and try again."
        }
        Start-Sleep -Milliseconds 500
    }

    Get-ChildItem -LiteralPath $InstallDir -Filter ".gunfare-backup-*" -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("gunfare-update-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $stage -Force
    $source = $stage
    $entries = @(Get-ChildItem -LiteralPath $stage -Force)
    if (-not (Test-Path -LiteralPath (Join-Path $stage $ExeName)) -and $entries.Count -eq 1 -and $entries[0].PSIsContainer) {
        $source = $entries[0].FullName
    }
    if (-not (Test-Path -LiteralPath (Join-Path $source $ExeName))) {
        throw "The package does not contain $ExeName."
    }

    $backup = Join-Path $InstallDir (".gunfare-backup-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($item in @(Get-ChildItem -LiteralPath $source -Force)) {
        $target = Join-Path $InstallDir $item.Name
        if (Test-Path -LiteralPath $target) {
            $saved = Join-Path $backup $item.Name
            Invoke-Retry { Move-Item -LiteralPath $target -Destination $saved -Force } ("Moving " + $item.Name)
            [void]$movedItems.Add(@($target, $saved))
        }
        [void]$placed.Add($target)
        Invoke-Retry { Copy-Item -LiteralPath $item.FullName -Destination $target -Recurse -Force } ("Copying " + $item.Name)
    }
    $canUnblock = [bool](Get-Command Unblock-File -ErrorAction SilentlyContinue)
    foreach ($target in $placed) {
        if (-not $canUnblock) {
            break
        }
        Get-ChildItem -LiteralPath $target -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
        }
    }
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "The new $ExeName is missing after the copy."
    }
    if ($Moved -eq "1") {
        Write-UpdateLog ("OK MOVED " + $InstallDir)
    }
    else {
        Write-UpdateLog "OK"
    }
    Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
    $backup = $null
    Start-Game
}
catch {
    $reason = $_.Exception.Message
    Write-Detail ("Error. " + $reason)
    Restore-OldFiles
    try { Write-UpdateLog ("FAIL " + $reason) } catch { }
    if ($backup -and (Test-Path -LiteralPath $backup)) {
        Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
    }
    Start-Game
    exit 1
}
finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}
