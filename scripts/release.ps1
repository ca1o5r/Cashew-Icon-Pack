<#
.SYNOPSIS
    Build, sign, install and release a new version of Cashew Icon Pack.
    Usage: .\scripts\release.ps1
    Usage with explicit tag: .\scripts\release.ps1 -VersionTag v3.2.0
#>

param(
    [string]$VersionTag = ""   # optional override, e.g. "v3.2.0"; auto-detected from MyApp.kt if empty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

# 1. Resolve version tag from buildSrc if not provided
if (-not $VersionTag) {
    $myAppKt = Get-Content "$root\buildSrc\src\main\java\MyApp.kt" -Raw
    if ($myAppKt -match 'versionName\s*=\s*"([^"]+)"') {
        $VersionTag = "v$($Matches[1])"
    } else {
        Write-Error "Could not detect versionName from MyApp.kt"
        exit 1
    }
}

Write-Host ""
Write-Host "=== Cashew Release Script: $VersionTag ===" -ForegroundColor Cyan

# 2. Kill stale Java/Gradle daemons to avoid locked files
Write-Host "`n[1/5] Stopping stale Java processes..." -ForegroundColor Yellow
Get-Process -Name "java","javaw" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

# 3. Build release APK
Write-Host "`n[2/5] Building release APK..." -ForegroundColor Yellow
Push-Location $root
& ".\gradlew.bat" clean assembleRelease --no-daemon
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Error "Build failed (exit code $LASTEXITCODE)"
    exit 1
}
Pop-Location

# 4. Find the APK
$apk = Get-ChildItem "$root\app\build\outputs\apk\release\*.apk" | Select-Object -First 1
if (-not $apk) { Write-Error "APK not found after build"; exit 1 }
Write-Host "APK: $($apk.Name) ($([math]::Round($apk.Length/1MB,1)) MB)" -ForegroundColor Green

# 5. Install on connected device (skip gracefully if none connected)
Write-Host "`n[3/5] Installing on device..." -ForegroundColor Yellow
$deviceLine = adb devices 2>&1 | Select-String "^\S+\s+device$"
if (-not $deviceLine) {
    Write-Warning "No device connected — skipping install and launch."
} else {
    adb uninstall com.cashew.iconpack 2>&1 | Out-Null
    adb install $apk.FullName
    if ($LASTEXITCODE -ne 0) { Write-Error "Install failed"; exit 1 }
    Write-Host "Installed successfully." -ForegroundColor Green
    adb shell am start -n com.cashew.iconpack/.MainActivity | Out-Null
    Write-Host "App launched on device." -ForegroundColor Green
}

# 6. Commit and push
Write-Host "`n[4/5] Committing and pushing to GitHub..." -ForegroundColor Yellow
git -C $root add -A
git -C $root commit -m "chore: release $VersionTag"
git -C $root push origin main
Write-Host "Pushed." -ForegroundColor Green

# 7. Create GitHub release
Write-Host "`n[5/5] Creating GitHub release $VersionTag..." -ForegroundColor Yellow
gh release create $VersionTag $apk.FullName `
    --title "$VersionTag" `
    --notes "Release $VersionTag"
Write-Host "Release created." -ForegroundColor Green

Write-Host "`n=== Done: $VersionTag ===" -ForegroundColor Cyan
