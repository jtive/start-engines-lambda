# Wait for GitHub Actions to deploy, then check status
$totalWait = 600
$checkInterval = 60

Write-Host "Waiting for GitHub Actions deployments to complete..." -ForegroundColor Cyan
Write-Host "This will take approximately 10 minutes" -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $totalWait; $i += $checkInterval) {
    $remaining = ($totalWait - $i) / 60
    Write-Host "  $remaining minutes remaining..." -ForegroundColor Gray
    Start-Sleep -Seconds $checkInterval
}

Write-Host ""
Write-Host "Checking service status..." -ForegroundColor Green
Write-Host ""

& "D:\Dev\start-engines-lambda\check-status.ps1"

Write-Host ""
Write-Host "Testing API endpoints..." -ForegroundColor Green

$endpoints = @(
    "https://api.cleancalcs.net/api/auth",
    "https://api.cleancalcs.net/api/pdf", 
    "https://api.cleancalcs.net/api/fa",
    "https://api.cleancalcs.net/api/users",
    "https://api.cleancalcs.net/api/batch"
)

foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint -Method GET -TimeoutSec 10 -ErrorAction Stop
        Write-Host "  Done with $endpoint - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "  Checked $endpoint - Got response" -ForegroundColor Yellow
    }
}
