# Build script for Yap Windows installer
# Prerequisites:
#   - Flutter SDK (in PATH)
#   - Inno Setup 6.x (default install location, or set $env:ISCC)
#
# Usage:
#   .\scripts\build_installer.ps1

param(
    [switch]$SkipFlutterBuild,
    [string]$InnoSetupPath
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "=== Yap — Windows Installer Build ===" -ForegroundColor Cyan

# --- Step 1: Build Flutter release ---
if (-not $SkipFlutterBuild) {
    Write-Host "`n[1/3] Building Flutter Windows release..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    try {
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "`n[1/3] Skipping Flutter build (using existing)" -ForegroundColor DarkGray
}

# --- Step 2: Verify build output ---
Write-Host "`n[2/3] Verifying build output..." -ForegroundColor Yellow
$BuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
$ExePath = Join-Path $BuildDir "yap.exe"

if (-not (Test-Path $ExePath)) {
    throw "Build output not found at $ExePath. Run without -SkipFlutterBuild."
}

$fileCount = (Get-ChildItem $BuildDir -Recurse -File).Count
Write-Host "  Found $fileCount files in build output"

# --- Step 3: Run Inno Setup compiler ---
Write-Host "`n[3/3] Compiling installer with Inno Setup..." -ForegroundColor Yellow

# Find ISCC.exe
$isccCandidates = @(
    $InnoSetupPath,
    $env:ISCC,
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) }

if ($isccCandidates.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: Inno Setup compiler (ISCC.exe) not found." -ForegroundColor Red
    Write-Host "Install Inno Setup 6 from: https://jrsoftware.org/isdl.php" -ForegroundColor Red
    Write-Host "Or set `$env:ISCC to the path of ISCC.exe" -ForegroundColor Red
    exit 1
}

$iscc = $isccCandidates[0]
Write-Host "  Using: $iscc"

$issFile = Join-Path $ProjectRoot "installer\yap.iss"
& $iscc $issFile
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed" }

# --- Done ---
$outputDir = Join-Path $ProjectRoot "build\installer"
$installer = Get-ChildItem $outputDir -Filter "*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host "`n=== Build complete! ===" -ForegroundColor Green
Write-Host "  Installer: $($installer.FullName)" -ForegroundColor Green
Write-Host "  Size: $([math]::Round($installer.Length / 1MB, 1)) MB" -ForegroundColor Green
