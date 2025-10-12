# Start All ECS Services
# Invokes the start-engines-lambda for each service

param(
    [string]$Environment = "dev",
    [string]$Region = "us-east-2",
    [string[]]$Services = @("auth", "pdf", "fa", "users", "batch"),
    [switch]$Force  # Skip confirmation
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "Start All ECS Services" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Services: $($Services -join ', ')" -ForegroundColor Yellow
Write-Host ""

# Confirmation prompt (unless -Force is used)
if (-not $Force) {
    $confirmation = Read-Host "Are you sure you want to start all services? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Starting all ECS services..." -ForegroundColor Cyan
Write-Host ""

$functionName = "start-engines-lambda-$Environment"
$results = @()

foreach ($service in $Services) {
    Write-Host "Starting $service..." -ForegroundColor Cyan
    
    $payloadFile = "$PSScriptRoot\example-events\start-$service-task.json"
    $responseFile = "$PSScriptRoot\response-start-$service.json"
    
    # Check if event file exists
    if (-not (Test-Path $payloadFile)) {
        Write-Host "  Warning: Event file not found: $payloadFile" -ForegroundColor Yellow
        $results += [PSCustomObject]@{
            Service = $service.ToUpper()
            Status = "SKIPPED"
            Message = "Event file not found"
        }
        continue
    }
    
    # Invoke Lambda
    aws lambda invoke `
        --function-name $functionName `
        --payload file://$payloadFile `
        --cli-binary-format raw-in-base64-out `
        --region $Region `
        $responseFile 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Started successfully" -ForegroundColor Green
        $results += [PSCustomObject]@{
            Service = $service.ToUpper()
            Status = "STARTED"
            Message = "Task started"
        }
    } else {
        Write-Host "  Failed to start" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Service = $service.ToUpper()
            Status = "FAILED"
            Message = "Lambda invocation failed"
        }
    }
    
    # Cleanup response file
    Remove-Item $responseFile -ErrorAction SilentlyContinue
    
    # Small delay between starts
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Summary" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$results | Format-Table -AutoSize

$successCount = ($results | Where-Object { $_.Status -eq "STARTED" }).Count
Write-Host ""
Write-Host "Services Started: $successCount / $($Services.Count)" -ForegroundColor $(if ($successCount -eq $Services.Count) { "Green" } else { "Yellow" })
Write-Host ""
Write-Host "Wait 60-90 seconds for tasks to start, then check status:" -ForegroundColor Cyan
Write-Host "  .\check-status.ps1" -ForegroundColor Gray
