# ==============================================================================
# One-line installer for standalone customized GNU nano (No Git required)
# Supports: Windows 10 / Windows 11 (PowerShell / Windows Terminal / CMD)
# Architectures: x86_64 (amd64), ARM64
# Usage:
#   irm https://raw.githubusercontent.com/LDQONJ/nano/main/install.ps1 | iex
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

$RepoOwner = "LDQONJ"
$RepoName = "nano"
$InstallDir = Join-Path $HOME ".nano"
$BinDir = Join-Path $InstallDir "bin"
$ShareDir = Join-Path $InstallDir "share"
$TerminfoDir = Join-Path $ShareDir "terminfo"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Info "Starting customized GNU nano standalone installer..."

# 1. Detect architecture
$TargetArch = "amd64"
if ([System.Environment]::Is64BitOperatingSystem) {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
        $TargetArch = "arm64"
    } else {
        $TargetArch = "amd64"
    }
} else {
    Write-Err "32-bit Windows is not supported. Please use 64-bit Windows."
    exit 1
}

Write-Info "Detected Windows architecture: $TargetArch"

# 2. Download standalone zip archive
$ArchiveName = "nano-windows-standalone-$TargetArch.zip"
$DownloadUrl = "https://github.com/$RepoOwner/$RepoName/releases/latest/download/$ArchiveName"
$TempZip = Join-Path ([System.IO.Path]::GetTempPath()) $ArchiveName

Write-Info "Downloading prebuilt standalone package from:"
Write-Info "  $DownloadUrl"

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZip -UseBasicParsing
} catch {
    Write-Warn "Could not download $ArchiveName. Falling back to amd64 package..."
    $ArchiveName = "nano-windows-standalone-amd64.zip"
    $DownloadUrl = "https://github.com/$RepoOwner/$RepoName/releases/latest/download/$ArchiveName"
    $TempZip = Join-Path ([System.IO.Path]::GetTempPath()) $ArchiveName
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZip -UseBasicParsing
}

# 3. Extract to $InstallDir
Write-Info "Extracting files to $InstallDir..."
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

try {
    Expand-Archive -Path $TempZip -DestinationPath $InstallDir -Force
} finally {
    if (Test-Path $TempZip) {
        Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
    }
}

# 4. Configure User PATH
$UserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($null -eq $UserPath) { $UserPath = "" }
$PathEntries = $UserPath -split ";" | Where-Object { $_ -ne "" }

if ($PathEntries -notcontains $BinDir) {
    Write-Info "Adding $BinDir to User PATH..."
    $NewUserPath = ($PathEntries + $BinDir) -join ";"
    [System.Environment]::SetEnvironmentVariable("PATH", $NewUserPath, "User")
}

# Also update current session PATH
if (($env:PATH -split ";") -notcontains $BinDir) {
    $env:PATH = "$BinDir;$env:PATH"
}

# 5. Configure TERMINFO environment variable
if (Test-Path $TerminfoDir) {
    Write-Info "Setting TERMINFO environment variable to $TerminfoDir..."
    [System.Environment]::SetEnvironmentVariable("TERMINFO", $TerminfoDir, "User")
    $env:TERMINFO = $TerminfoDir
}

# 6. Ensure TERM defaults to xterm-256color if unset
$UserTerm = [System.Environment]::GetEnvironmentVariable("TERM", "User")
if (-not $UserTerm) {
    [System.Environment]::SetEnvironmentVariable("TERM", "xterm-256color", "User")
    $env:TERM = "xterm-256color"
}

# 7. Verification
$NanoExe = Join-Path $BinDir "nano.exe"
if (Test-Path $NanoExe) {
    $NanoVer = & "$NanoExe" --version | Select-Object -First 1
    Write-Success "Installation complete! $NanoVer"
    Write-Host ""
    Write-Host "Custom features active by default:" -ForegroundColor Cyan
    Write-Host "  - Alt + Up/Down       : Duplicate current line up/down" -ForegroundColor White
    Write-Host "  - Alt + Shift + Up/Down: Move current line up/down" -ForegroundColor White
    Write-Host "  - Tab width = 4       : Changed from default 8 to 4 spaces" -ForegroundColor White
    Write-Host "  - Auto-indent         : Keeps indentation on Enter" -ForegroundColor White
    Write-Host "  - Syntax highlighting : Enabled by default for all languages" -ForegroundColor White
    Write-Host ""
    Write-Host "You can now run 'nano' directly in PowerShell, CMD, or Windows Terminal!" -ForegroundColor Green
} else {
    Write-Err "Could not find nano.exe at $NanoExe."
    exit 1
}
