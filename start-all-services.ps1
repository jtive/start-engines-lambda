# Start All ECS Services
# Invokes the start-engines-lambda for each service

param(
    [string]$Environment = "dev",
    [string]$Region = "us-east-2",
    [string[]]$Services = @("auth", "pdf", "fa", "users", "batch"),
    [switch]$Force  # Skip confirmation
)

# Map each service to its cluster and service name
$ServiceClusterMap = @{
    "auth"  = @{ cluster = "authapi-cluster"; service = "authapi-service" }
    "pdf"   = @{ cluster = "pdfcreator-cluster"; service = "pdfcreator-service" }
    "fa"    = @{ cluster = "fa-engine-cluster"; service = "fa-engine-service" }
    "users" = @{ cluster = "user-management-cluster"; service = "user-management-service" }
    "batch" = @{ cluster = "batch-engine"; service = "batch-engine-service" }
}

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
    
    $serviceConfig = $ServiceClusterMap[$service]
    $cluster = $serviceConfig.cluster
    $serviceName = $serviceConfig.service
    
    # Update ECS service desired count to 1
    Write-Host "  Updating service desired count to 1 in cluster $cluster..." -ForegroundColor Cyan
    $updateOutput = aws ecs update-service `
        --cluster $cluster `
        --service $serviceName `
        --desired-count 1 `
        --region $Region 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Service started successfully" -ForegroundColor Green
        $results += [PSCustomObject]@{
            Service = $service.ToUpper()
            Cluster = $cluster
            Status = "STARTED"
            Message = "Desired count set to 1"
        }
    } else {
        Write-Host "  Error starting service: $updateOutput" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Service = $service.ToUpper()
            Cluster = $cluster
            Status = "FAILED"
            Message = "Failed to update desired count"
        }
    }
    
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
