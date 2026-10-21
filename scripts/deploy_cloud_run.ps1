# ==============================================================================
# Google Cloud Run Deploy Script (PowerShell)
# ==============================================================================

param(
    [string]$ProjectId = "project-c5416966-d0c7-49c5-add",
    [string]$Region = "australia-southeast1"
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Home Inventory - Google Cloud Run Deployer" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Check gcloud
if (-not (Get-Command "gcloud" -ErrorAction SilentlyContinue)) {
    Write-Host "[x] Google Cloud SDK (gcloud CLI) not found." -ForegroundColor Red
    exit 1
}

Write-Host "[*] GCP Project: $ProjectId" -ForegroundColor Green
Write-Host "[*] GCP Region:  $Region" -ForegroundColor Green

# 1. Parse .env
$envPath = Join-Path $PSScriptRoot "..\.env"
$envVars = @()
if (Test-Path $envPath) {
    Write-Host "[*] Loading .env variables..." -ForegroundColor Gray
    Get-Content $envPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim()
            if ($k -in @("DATABASE_URL", "DB_SCHEMA", "GEMINI_API_KEY", "GEMINI_MODEL", "GEMINI_EMBEDDING_MODEL", "CF_ACCOUNT_ID", "R2_BUCKET_NAME", "R2_PUBLIC_DOMAIN", "APP_ENV", "SUPABASE_PROJECT_REF", "SUPABASE_URL")) {
                $envVars += "$k=$v"
            }
        }
    }
}
$envArg = if ($envVars.Count -gt 0) { "--set-env-vars `"" + ($envVars -join ",") + "`"" } else { "" }

# 2. Build backend Docker image with Google Cloud Build & Artifact Registry
$ImageTag = "australia-southeast1-docker.pkg.dev/$ProjectId/cloud-run-source-deploy/home-inventory-backend:latest"
Write-Host "`n[*] Building container image via Google Cloud Build: $ImageTag ..." -ForegroundColor Yellow
$backendDir = Join-Path $PSScriptRoot "..\backend"
gcloud builds submit $backendDir --tag $ImageTag --project $ProjectId

if ($LASTEXITCODE -ne 0) {
    Write-Host "[x] Cloud Build failed. Please check build error logs above." -ForegroundColor Red
    exit 1
}

# 3. Deploy to Cloud Run
Write-Host "`n[*] Deploying service to Google Cloud Run..." -ForegroundColor Yellow

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
    Write-Host "`n[+] Cloud Run Deployment Succeeded!" -ForegroundColor Green
    $serviceUrl = (gcloud run services describe home-inventory-backend --platform managed --region $Region --format "value(status.url)" --project $ProjectId).Trim()
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " Cloud Run Service URL: $serviceUrl" -ForegroundColor Green
    Write-Host " Swagger API Docs:      $serviceUrl/docs" -ForegroundColor White
    Write-Host " Custom Domain:         https://homeinv.advaz.au" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
} else {
    Write-Host "[x] Cloud Run Deployment failed." -ForegroundColor Red
}
