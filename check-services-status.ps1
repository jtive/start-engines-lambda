# Check Status of All ECS Services
# Shows running tasks, target health, and Lambda status

param(
    [string]$Region = "us-east-2",
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ECS Services Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host ""

# Service to cluster mapping
$services = @{
    "auth" = @{
        cluster = "auth-cluster"
        targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-auth-tg/cecaa72dcd652062"
        port = 8080
    }
    "pdf" = @{
        cluster = "pdf-cluster"
        targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-pdf-tg/c608c00789aa70a9"
        port = 9080
    }
    "fa" = @{
        cluster = "fa-cluster"
        targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-fa-tg/c1c35818b5273bfc"
        port = 2531
    }
    "users" = @{
        cluster = "users-cluster"
        targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/users-tg/f9a22b2edc13281f"
        port = 8080
    }
    "batch" = @{
        cluster = "batch-cluster"
        targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/batch-tg/4016a351002f823f"
        port = 8080
    }
}

$statusTable = @()

foreach ($serviceName in $services.Keys | Sort-Object) {
    $config = $services[$serviceName]
    
    Write-Host "Checking $serviceName..." -ForegroundColor Cyan
    
    try {
        # Check ECS tasks
        $tasksJson = aws ecs list-tasks `
            --cluster $config.cluster `
            --desired-status RUNNING `
            --region $Region 2>&1
        
        $runningTasks = 0
        if ($LASTEXITCODE -eq 0) {
            $tasks = $tasksJson | ConvertFrom-Json
            $runningTasks = $tasks.taskArns.Count
        }
        
        # Check target health
        $healthyTargets = 0
        $unhealthyTargets = 0
        
        try {
            $healthJson = aws elbv2 describe-target-health `
                --target-group-arn $config.targetGroup `
                --region $Region 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $health = $healthJson | ConvertFrom-Json
                $healthyTargets = ($health.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
                $unhealthyTargets = ($health.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -ne "healthy" }).Count
            }
        }
        catch {
            # Target group might not exist or no targets registered
        }
        
        $status = if ($runningTasks -gt 0 -and $healthyTargets -gt 0) {
            "Running & Healthy"
        } elseif ($runningTasks -gt 0) {
            "Running (Unhealthy)"
        } else {
            "Stopped"
        }
        
        $statusTable += [PSCustomObject]@{
            Service = $serviceName.ToUpper()
            Cluster = $config.cluster
            RunningTasks = $runningTasks
            HealthyTargets = $healthyTargets
            UnhealthyTargets = $unhealthyTargets
            Port = $config.port
            Status = $status
        }
    }
    catch {
        $statusTable += [PSCustomObject]@{
            Service = $serviceName.ToUpper()
            Cluster = $config.cluster
            RunningTasks = "Error"
            HealthyTargets = "Error"
            UnhealthyTargets = "Error"
            Port = $config.port
            Status = "Error"
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Services Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$statusTable | Format-Table -AutoSize

# Count totals
$totalRunning = ($statusTable | Where-Object { $_.Status -like "*Running*" }).Count
$totalStopped = ($statusTable | Where-Object { $_.Status -eq "Stopped" }).Count
$totalHealthy = ($statusTable | Measure-Object -Property HealthyTargets -Sum).Sum

Write-Host ""
Write-Host "Total Services Running: $totalRunning" -ForegroundColor $(if ($totalRunning -gt 0) { "Green" } else { "Yellow" })
Write-Host "Total Services Stopped: $totalStopped" -ForegroundColor $(if ($totalStopped -gt 0) { "Yellow" } else { "Green" })
Write-Host "Total Healthy Targets: $totalHealthy" -ForegroundColor $(if ($totalHealthy -gt 0) { "Green" } else { "Yellow" })

# Check Lambda functions
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lambda Functions Status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$lambdas = @(
    "start-engines-lambda-$Environment",
    "stop-engines-lambda-$Environment"
)

foreach ($lambda in $lambdas) {
    try {
        $funcJson = aws lambda get-function --function-name $lambda --region $Region 2>&1
        if ($LASTEXITCODE -eq 0) {
            $func = $funcJson | ConvertFrom-Json
            Write-Host "✓ $lambda" -ForegroundColor Green
            Write-Host "  State: $($func.Configuration.State)" -ForegroundColor Gray
            Write-Host "  Runtime: $($func.Configuration.Runtime)" -ForegroundColor Gray
        }
        else {
            Write-Host "✗ $lambda - Not found" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ $lambda - Error checking status" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Quick Actions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Start all services:" -ForegroundColor Yellow
Write-Host "  .\start-all-services.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Stop all services:" -ForegroundColor Yellow
Write-Host "  .\stop-all-services.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Start single service:" -ForegroundColor Yellow
Write-Host "  .\start-single-service.ps1 -Service auth" -ForegroundColor Gray
Write-Host ""
Write-Host "Stop single service:" -ForegroundColor Yellow
Write-Host "  .\stop-single-service.ps1 -Service auth" -ForegroundColor Gray
Write-Host ""
