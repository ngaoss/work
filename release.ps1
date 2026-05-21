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
    $jsonRaw.macosUrl = "https://github.com/ngaoss/work/raw/main/dist/$NewVersion/DeepCodeWork.dmg"
    $jsonRaw.androidUrl = "https://github.com/ngaoss/work/raw/main/dist/$NewVersion/DeepCodeWork.apk"
    
    if ($null -eq $jsonRaw.downloadUrl) {
        $jsonRaw | Add-Member -MemberType NoteProperty -Name "downloadUrl" -Value "https://github.com/ngaoss/work/raw/main/dist/$NewVersion/DeepCodeWork_Setup.exe"
    } else {
        $jsonRaw.downloadUrl = "https://github.com/ngaoss/work/raw/main/dist/$NewVersion/DeepCodeWork_Setup.exe"
    }
    
    $jsonRaw | ConvertTo-Json | Set-Content $jsonPath
}

# 4. Build Flutter Windows
Write-Host "Building Flutter Windows (Release)..."
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "Build Windows failed!" }

# 5. Build Flutter Android APK (Split per ABI for smaller size)
Write-Host "Building Flutter Android APK (Release - Split per ABI)..."
flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { throw "Build APK failed!" }

# 6. Run Inno Setup Compiler (ISCC)
Write-Host "Packaging with Inno Setup (Windows)..."
if (Get-Command "iscc" -ErrorAction SilentlyContinue) {
    & "iscc" installer.iss
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed!" }
} elseif (Test-Path "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe") {
    & "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" installer.iss
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed!" }
} else {
    Write-Warning "ISCC.exe not found. Please add Inno Setup to your PATH or install it to the default location."
}

# 7. Organize Dist Folder (Moving APK)
Write-Host "Organizing dist/$NewVersion folder..."
$targetDist = "dist/$NewVersion"
if (!(Test-Path $targetDist)) {
    New-Item -ItemType Directory -Path $targetDist
}

# Copy the arm64-v8a APK to dist folder (usually the smallest and most common)
$apkPath = "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if (!(Test-Path $apkPath)) {
    # Fallback to standard name if not split
    $apkPath = "build/app/outputs/flutter-apk/app-release.apk"
}

if (Test-Path $apkPath) {
    Copy-Item $apkPath "$targetDist/DeepCodeWork.apk"
    Write-Host "Optimized APK (arm64) renamed and copied to $targetDist/DeepCodeWork.apk"
}

# 8. Git Push
Write-Host "Pushing changes to GitHub..."
git add .
git commit -m "Release version $NewVersion (Windows & Android)"
git push

Write-Host "SUCCESS: Version $NewVersion release completed (Windows & Android)." -ForegroundColor Green

