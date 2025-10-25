# Stop All ECS Services
# Invokes the stop-engines-lambda to stop all running tasks

param(
    [string]$Environment = "dev",
    [string]$Region = "us-east-2",
    [string[]]$Services = @("auth", "pdf", "fa", "users", "batch"),
    [switch]$Force  # Skip confirmation
)

# Map each service to its cluster
$ServiceClusterMap = @{
    "auth"  = @{ cluster = "authapi-cluster"; service = "authapi-service" }
    "pdf"   = @{ cluster = "pdfcreator-cluster"; service = "pdfcreator-service" }
    "fa"    = @{ cluster = "fa-engine-cluster"; service = "fa-engine-service" }
    "users" = @{ cluster = "user-management-cluster"; service = "user-management-service" }
    "batch" = @{ cluster = "batch-engine"; service = "batch-engine-service" }
}

Write-Host "========================================" -ForegroundColor Red
Write-Host "Stop All ECS Services" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Services: $($Services -join ', ')" -ForegroundColor Yellow
Write-Host ""

# Confirmation prompt (unless -Force is used)
if (-not $Force) {
    $confirmation = Read-Host "Are you sure you want to stop all services? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Stopping all ECS tasks..." -ForegroundColor Cyan
Write-Host ""

# Invoke Lambda to stop all running tasks (including manually running ones)
$functionName = "stop-engines-lambda-$Environment"
$payloadFile = "$PSScriptRoot\example-events\stop-all-tasks.json"
$responseFile = "$PSScriptRoot\response-stop-all.json"

Write-Host "Invoking Lambda: $functionName to stop all running tasks" -ForegroundColor Cyan

aws lambda invoke `
    --function-name $functionName `
    --payload file://$payloadFile `
    --cli-binary-format raw-in-base64-out `
    --region $Region `
    $responseFile 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Lambda invoked successfully" -ForegroundColor Green
    
    # Parse Lambda response
    $response = Get-Content $responseFile -Raw | ConvertFrom-Json
    if ($response.body) {
        Write-Host "Message: $($response.body.message)" -ForegroundColor Yellow
        if ($response.body.total_tasks_stopped) {
            Write-Host "Total Tasks Stopped: $($response.body.total_tasks_stopped)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "Warning: Lambda invocation failed, continuing with service updates" -ForegroundColor Yellow
}

Write-Host ""

# Update ECS service desired counts to 0
Write-Host "Updating service desired counts to 0..." -ForegroundColor Cyan
foreach ($service in $Services) {
    $clusterInfo = $ServiceClusterMap[$service]
    $cluster = $clusterInfo.cluster
    $serviceName = $clusterInfo.service
    Write-Host "  Stopping $service in cluster $cluster..." -ForegroundColor Cyan
    $updateOutput = aws ecs update-service `
        --cluster $cluster `
        --service $serviceName `
        --desired-count 0 `
        --region $Region 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    $service stopped successfully" -ForegroundColor Green
    } else {
        Write-Host "    Error stopping $service : $updateOutput" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "All services stopped successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
