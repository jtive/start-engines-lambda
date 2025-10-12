# Quick script to start the remaining services
$services = @("pdf", "fa", "users", "batch")
$region = "us-east-2"

Write-Host "Starting remaining services..." -ForegroundColor Green
Write-Host ""

foreach ($service in $services) {
    Write-Host "Starting $service..." -ForegroundColor Cyan
    
    $payload = @{
        source = "custom.app"
        "detail-type" = "Start ECS Task"
        detail = @{
            service = $service
        }
    } | ConvertTo-Json -Compress
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    $payload | Out-File -FilePath $tempFile -Encoding utf8 -NoNewline
    
    aws lambda invoke `
        --function-name start-engines-lambda-dev `
        --payload "file://$tempFile" `
        --cli-binary-format raw-in-base64-out `
        --region $region `
        output.json | Out-Null
    
    Remove-Item $tempFile -ErrorAction SilentlyContinue
    
    Write-Host "  ✓ $service start initiated" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

Remove-Item output.json -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "All services started!" -ForegroundColor Green
Write-Host "Wait 60 seconds for tasks to start, then run: .\check-status.ps1" -ForegroundColor Yellow

