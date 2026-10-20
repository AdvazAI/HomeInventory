# ==============================================================================
# Google Cloud Run 部署自動化腳本 (PowerShell)
# ==============================================================================

param(
    [string]$ProjectId = "project-c5416966-d0c7-49c5-add",
    [string]$Region = "australia-southeast1"
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " 家庭庫存系統 (Home Inventory) Google Cloud Run 部署工具" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 檢查 gcloud 是否安裝
if (-not (Get-Command "gcloud" -ErrorAction SilentlyContinue)) {
    Write-Host "[x] 未偵測到 Google Cloud SDK (gcloud CLI)。" -ForegroundColor Red
    Write-Host "    請先下載安裝 Google Cloud SDK: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

# 若未輸入 ProjectId，嘗試自動獲取當前 gcloud 專案
if (-not $ProjectId) {
    $ProjectId = (gcloud config get-value project 2>$null).Trim()
    if (-not $ProjectId -or $ProjectId -eq "(unset)") {
        $ProjectId = Read-Host "請輸入您的 Google Cloud Project ID"
    }
}

Write-Host "[*] 使用 Google Cloud 專案: $ProjectId" -ForegroundColor Green
Write-Host "[*] 目標地區: $Region" -ForegroundColor Green

# 載入 .env 環境變數
$envPath = Join-Path $PSScriptRoot "..\.env"
$envVars = @()
if (Test-Path $envPath) {
    Write-Host "[*] 正在載入 .env 環境變數..." -ForegroundColor Gray
    Get-Content $envPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim()
            if ($k -in @("DATABASE_URL", "DB_SCHEMA", "GEMINI_API_KEY", "CF_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET_NAME", "R2_PUBLIC_DOMAIN", "APP_ENV")) {
                $envVars += "$k=$v"
            }
        }
    }
}
$envArg = if ($envVars.Count -gt 0) { "--set-env-vars `"" + ($envVars -join ",") + "`"" } else { "" }

# 1. 啟用 Google Cloud 必要服務 API (Cloud Run, Cloud Build, Artifact Registry)
Write-Host "`n[*] 正在檢查並啟用 Cloud Run 與 Cloud Build APIs..." -ForegroundColor Yellow
gcloud services enable run.googleapis.com cloudbuild.googleapis.com containerregistry.googleapis.com --project $ProjectId

# 2. 使用 Cloud Build 雲端建置後端 Docker 容器映像檔
$ImageTag = "gcr.io/$ProjectId/home-inventory-backend:latest"
Write-Host "`n[*] 正在透過 Google Cloud Build 建置容器映像檔: $ImageTag ..." -ForegroundColor Yellow
$backendDir = Join-Path $PSScriptRoot "..\backend"
gcloud builds submit $backendDir --tag $ImageTag --project $ProjectId

if ($LASTEXITCODE -ne 0) {
    Write-Host "[x] 容器建置失敗，請檢查錯誤日誌。" -ForegroundColor Red
    exit 1
}

# 3. 部署至 Google Cloud Run
Write-Host "`n[*] 正在部署至 Google Cloud Run (無伺服器容器)..." -ForegroundColor Yellow

# 組合環境變數參數
$deployCmd = "gcloud run deploy home-inventory-backend " +
             "--image $ImageTag " +
             "--platform managed " +
             "--region $Region " +
             "--allow-unauthenticated " +
             "--port 8080 " +
             "$envArg " +
             "--project $ProjectId"

Invoke-Expression $deployCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[✓] 部署成功！" -ForegroundColor Green
    $serviceUrl = (gcloud run services describe home-inventory-backend --platform managed --region $Region --format "value(status.url)" --project $ProjectId).Trim()
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " 後端 Cloud Run 服務網址:" -ForegroundColor Green
    Write-Host " $serviceUrl" -ForegroundColor White
    Write-Host " Swagger API 文件: $serviceUrl/docs" -ForegroundColor White
    Write-Host " 請將此網址填入 Flutter App 的 Base URL 設定中即可連線！" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
} else {
    Write-Host "[x] Cloud Run 部署失敗。" -ForegroundColor Red
}
