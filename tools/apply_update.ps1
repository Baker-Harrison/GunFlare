# GUNFARE_UPDATE_SCRIPT_WINDOWS
# Wait until the game stops. Copy the new files. Start the game again.
param(
    [Parameter(Mandatory = $true)][int]$WaitPid,
    [Parameter(Mandatory = $true)][string]$ZipPath,
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$ExeName,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$Moved = ""
)

$ErrorActionPreference = "Stop"
$stage = $null

function Write-UpdateLog($text) {
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -Path $LogPath -Value $text -Encoding utf8
}

try {
    $deadline = (Get-Date).AddMinutes(2)
    while (Get-Process -Id $WaitPid -ErrorAction SilentlyContinue) {
        if ((Get-Date) -gt $deadline) {
            throw "The game process did not stop."
        }
        Start-Sleep -Milliseconds 400
    }
    Start-Sleep -Seconds 1
    $stage = Join-Path $env:TEMP ("gunfare-update-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $stage | Out-Null
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $stage -Force
    $source = $stage
    $entries = @(Get-ChildItem -LiteralPath $stage)
    $exeAtRoot = Test-Path -LiteralPath (Join-Path $stage $ExeName)
    if (-not $exeAtRoot -and $entries.Count -eq 1 -and $entries[0].PSIsContainer) {
        $source = $entries[0].FullName
    }
    if (-not (Test-Path -LiteralPath (Join-Path $source $ExeName))) {
        throw "The package does not contain $ExeName."
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    # A virus scanner or Explorer can hold a file for a short time after the game stops.
    $attempt = 0
    while ($true) {
        try {
            Copy-Item -Path (Join-Path $source "*") -Destination $InstallDir -Recurse -Force
            break
        }
        catch {
            $attempt += 1
            if ($attempt -ge 30) {
                throw
            }
            Start-Sleep -Seconds 1
        }
    }
    if ($Moved -eq "1") {
        Write-UpdateLog ("OK MOVED " + $InstallDir)
    }
    else {
        Write-UpdateLog "OK"
    }
    Start-Process -FilePath (Join-Path $InstallDir $ExeName) -WorkingDirectory $InstallDir
}
catch {
    Write-UpdateLog ("FAIL " + $_.Exception.Message)
    $existing = Join-Path $InstallDir $ExeName
    if (Test-Path -LiteralPath $existing) {
        Start-Process -FilePath $existing -WorkingDirectory $InstallDir
    }
    exit 1
}
finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}
