# Check Status of All ECS Services
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
    "auth" = @{ cluster = "authapi-cluster"; targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-auth-tg/cecaa72dcd652062"; port = 8080 }
    "pdf" = @{ cluster = "pdfcreator-cluster"; targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-pdf-tg/c608c00789aa70a9"; port = 80 }
    "fa" = @{ cluster = "fa-engine-cluster"; targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-fa-tg/c1c35818b5273bfc"; port = 2531 }
    "users" = @{ cluster = "user-management-cluster"; targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/users-tg/f9a22b2edc13281f"; port = 8080 }
    "batch" = @{ cluster = "batch-engine"; targetGroup = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/batch-tg/4016a351002f823f"; port = 8080 }
}

$statusTable = @()

foreach ($serviceName in $services.Keys | Sort-Object) {
    $config = $services[$serviceName]
    Write-Host "Checking $serviceName..." -ForegroundColor Cyan
    
    try {
        # Check ECS tasks
        $tasksJson = aws ecs list-tasks --cluster $config.cluster --desired-status RUNNING --region $Region 2>&1
        $runningTasks = 0
        if ($LASTEXITCODE -eq 0) {
            $tasks = $tasksJson | ConvertFrom-Json
            $runningTasks = $tasks.taskArns.Count
        }
        
        # Check target health
        $healthyTargets = 0
        $unhealthyTargets = 0
        
        try {
            $healthJson = aws elbv2 describe-target-health --target-group-arn $config.targetGroup --region $Region 2>&1
            if ($LASTEXITCODE -eq 0) {
                $health = $healthJson | ConvertFrom-Json
                $healthyTargets = ($health.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
                $unhealthyTargets = ($health.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -ne "healthy" }).Count
            }
        } catch {
            # Target group might not exist or no targets registered
        }
        
        $status = if ($runningTasks -gt 0 -and $healthyTargets -gt 0) { "Running & Healthy" } 
                  elseif ($runningTasks -gt 0) { "Running (Unhealthy)" } 
                  else { "Stopped" }
        
        $statusTable += [PSCustomObject]@{
            Service = $serviceName.ToUpper()
            Cluster = $config.cluster
            RunningTasks = $runningTasks
            HealthyTargets = $healthyTargets
            UnhealthyTargets = $unhealthyTargets
            Port = $config.port
            Status = $status
        }
    } catch {
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
Write-Host ""

