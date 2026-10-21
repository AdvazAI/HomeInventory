param (
    [Parameter(Mandatory=$false)]
    [string]$Seq = "01"
)

$today = (Get-Date).ToString("yyMMdd")
$versionName = "$today.$Seq"
$versionCode = [int]("${today}$Seq")

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Building HomeInventory Android App Bundle" -ForegroundColor Cyan
Write-Host "Package ID:   au.advaz.homeinventory" -ForegroundColor Yellow
Write-Host "Version Name: $versionName" -ForegroundColor Yellow
Write-Host "Version Code: $versionCode" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan

Set-Location -Path "$PSScriptRoot\..\frontend"
flutter build appbundle --release --build-name=$versionName --build-number=$versionCode

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[SUCCESS] App Bundle built successfully!" -ForegroundColor Green
    $aabPath = "$PSScriptRoot\..\frontend\build\app\outputs\bundle\release\app-release.aab"
    Get-Item $aabPath | Select-Object FullName, Length, LastWriteTime
    explorer.exe /select,"$aabPath"
} else {
    Write-Host "`n[ERROR] Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
