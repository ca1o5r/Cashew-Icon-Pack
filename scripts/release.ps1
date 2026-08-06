<#
.SYNOPSIS
    Build, sign, install and release a new version of Cashew Icon Pack.
    Usage: .\scripts\release.ps1
    Usage with explicit tag: .\scripts\release.ps1 -VersionTag v3.4.0
    Custom commit message:   .\scripts\release.ps1 -CommitMsg "feat: ..."
#>

param(
    [string]$VersionTag = "",
    [string]$CommitMsg  = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

# ── 1. Resolve version tag ──────────────────────────────────────────────
if (-not $VersionTag) {
    $myAppKt = Get-Content "$root\buildSrc\src\main\java\MyApp.kt" -Raw
    if ($myAppKt -match 'versionName\s*=\s*"([^"]+)"') {
        $VersionTag = "v$($Matches[1])"
    } else {
        Write-Error "Could not detect versionName from MyApp.kt"
        exit 1
    }
}

if (-not $CommitMsg) { $CommitMsg = "chore: release $VersionTag" }

Write-Host ""
Write-Host "=== Cashew Release Script: $VersionTag ===" -ForegroundColor Cyan

# ── 2. Clean up temp / debug files ──────────────────────────────────────
Write-Host "`n[1/6] Cleaning temp files..." -ForegroundColor Yellow

# Local: remove verify/debug screenshots in project root
Get-ChildItem "$root" -Filter "verify*.png" -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item $_.FullName -Force; Write-Host "  Deleted: $($_.Name)" }
Get-ChildItem "$root" -Filter "final_verify*" -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item $_.FullName -Force; Write-Host "  Deleted: $($_.Name)" }

# Local: remove Blueprint temp extractions
@("$env:TEMP\blueprint-aar", "$env:TEMP\blueprint-src") | ForEach-Object {
    if (Test-Path $_) { Remove-Item $_ -Recurse -Force; Write-Host "  Deleted: $_" }
}

# Phone: remove any debug screenshots pushed to /sdcard/
$deviceLine = adb devices 2>&1 | Select-String "^\S+\s+device$"
if ($deviceLine) {
    adb shell rm -f /sdcard/verify*.png /sdcard/screenshot_*.png 2>&1 | Out-Null
    Write-Host "  Cleaned phone temp files." -ForegroundColor Green
} else {
    Write-Host "  No device connected — skipping phone cleanup." -ForegroundColor DarkGray
}
Write-Host "Cleanup done." -ForegroundColor Green

# ── 3. Kill stale Java/Gradle daemons ────────────────────────────────────
Write-Host "`n[2/6] Stopping stale Java processes..." -ForegroundColor Yellow
Get-Process -Name "java","javaw" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

# ── 4. Build release APK ────────────────────────────────────────────────
Write-Host "`n[3/6] Building release APK..." -ForegroundColor Yellow
Push-Location $root
& ".\gradlew.bat" clean assembleRelease --no-daemon
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Error "Build failed (exit code $LASTEXITCODE)"
    exit 1
}
Pop-Location

# ── 5. Find the APK ─────────────────────────────────────────────────────
$apk = Get-ChildItem "$root\app\build\outputs\apk\release\*.apk" | Select-Object -First 1
if (-not $apk) { Write-Error "APK not found after build"; exit 1 }
Write-Host "APK: $($apk.Name) ($([math]::Round($apk.Length/1MB,1)) MB)" -ForegroundColor Green

# ── 6. Install on connected device ──────────────────────────────────────
Write-Host "`n[4/6] Installing on device..." -ForegroundColor Yellow
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

# ── 7. Commit and push ──────────────────────────────────────────────────
Write-Host "`n[5/6] Committing and pushing to GitHub..." -ForegroundColor Yellow
git -C $root add -A
git -C $root diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "No changes to commit." -ForegroundColor DarkGray
} else {
    git -C $root commit -m $CommitMsg
    git -C $root push origin main
    Write-Host "Pushed." -ForegroundColor Green
}

# ── 8. Create GitHub release ────────────────────────────────────────────
Write-Host "`n[6/6] Creating GitHub release $VersionTag..." -ForegroundColor Yellow
gh release create $VersionTag $apk.FullName `
    --title "$VersionTag" `
    --notes "Release $VersionTag"
Write-Host "Release created." -ForegroundColor Green

Write-Host "`n=== Done: $VersionTag ===" -ForegroundColor Cyan

