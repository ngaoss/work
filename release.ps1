# Automation Script for DeepCode Work Build and Release
# Usage: .\release.ps1 -NewVersion "1.0.3"

param (
    [Parameter(Mandatory=$true)]
    [string]$NewVersion
)

$ErrorActionPreference = "Stop"

Write-Host "Started release process for version $NewVersion..." -ForegroundColor Cyan

# 1. Update pubspec.yaml
Write-Host "Updating pubspec.yaml..."
$pubspecPath = "pubspec.yaml"
if (Test-Path $pubspecPath) {
    (Get-Content $pubspecPath) -replace 'version: .+', "version: $NewVersion" | Set-Content $pubspecPath
}

# 2. Update installer.iss
Write-Host "Updating installer.iss..."
$issPath = "installer.iss"
if (Test-Path $issPath) {
    (Get-Content $issPath) -replace '#define MyAppVersion ".+"', "#define MyAppVersion ""$NewVersion""" | Set-Content $issPath
}

# 3. Update version.json
Write-Host "Updating version.json..."
$jsonPath = "version.json"
if (Test-Path $jsonPath) {
    $jsonRaw = Get-Content $jsonPath -Raw | ConvertFrom-Json
    $jsonRaw.version = $NewVersion
    $jsonRaw.windowsUrl = "https://github.com/ngaoss/work/raw/main/dist/$NewVersion/DeepCodeWork_Setup.exe"
    $jsonRaw.androidUrl = "https://github.com/ngaoss/work/raw/main/dist/$NewVersion/app-release.apk"
    $jsonRaw.downloadUrl = "https://github.com/ngaoss/work/raw/main/dist/$NewVersion/DeepCodeWork_Setup.exe"
    $jsonRaw | ConvertTo-Json | Set-Content $jsonPath
}

# 4. Build Flutter Windows
Write-Host "Building Flutter Windows (Release)..."
flutter build windows --release

# 5. Build Flutter Android APK
Write-Host "Building Flutter Android APK (Release)..."
flutter build apk --release

# 6. Run Inno Setup Compiler (ISCC)
Write-Host "Packaging with Inno Setup (Windows)..."
if (Get-Command "iscc" -ErrorAction SilentlyContinue) {
    & "iscc" installer.iss
} elseif (Test-Path "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe") {
    & "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" installer.iss
} else {
    Write-Warning "ISCC.exe not found. Please add Inno Setup to your PATH or install it to the default location."
}

# 7. Organize Dist Folder (Moving APK)
Write-Host "Organizing dist/$NewVersion folder..."
$targetDist = "dist/$NewVersion"
if (!(Test-Path $targetDist)) {
    New-Item -ItemType Directory -Path $targetDist
}

# Copy Android APK to dist folder (ISCC already handled Windows exe)
$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
if (Test-Path $apkPath) {
    Copy-Item $apkPath "$targetDist/app-release.apk"
    Write-Host "APK copied to $targetDist"
}

# 8. Git Push
Write-Host "Pushing changes to GitHub..."
git add .
git commit -m "Release version $NewVersion (Windows & Android)"
git push

Write-Host "SUCCESS: Version $NewVersion release completed (Windows & Android)." -ForegroundColor Green

