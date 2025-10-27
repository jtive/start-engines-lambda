# Sync Target Groups with Running ECS Tasks
# Gets currently running ECS tasks and ensures target groups match
# Removes unhealthy targets and registers healthy ones

param(
    [string]$Region = "us-east-2",
    [string[]]$Services = @("auth", "pdf", "fa", "users", "batch"),
    [switch]$Force
)

$ErrorActionPreference = "Continue"

# Service configuration
$serviceConfigs = @{
    "auth" = @{
        cluster = "authapi-cluster"
        targetGroupArn = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-auth-tg/cecaa72dcd652062"
        port = 8080
    }
    "pdf" = @{
        cluster = "pdfcreator-cluster"
        targetGroupArn = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-pdf-tg/c608c00789aa70a9"
        port = 80
    }
    "fa" = @{
        cluster = "fa-engine-cluster"
        targetGroupArns = @(
            "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-fa-tg/c1c35818b5273bfc",
            "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/fa-engine-tg/dbcce8724f4dc4bd"
        )
        port = 2531
    }
    "users" = @{
        cluster = "user-management-cluster"
        targetGroupArn = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/users-tg/f9a22b2edc13281f"
        port = 8080
    }
    "batch" = @{
        cluster = "batch-engine"
        targetGroupArn = "arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/batch-tg/4016a351002f823f"
        port = 8080
    }
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Sync Target Groups with ECS Tasks" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Services: $($Services -join ', ')" -ForegroundColor Yellow
Write-Host ""

if (-not $Force) {
    $confirmation = Read-Host "This will sync target groups with running tasks. Continue? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
$results = @()

foreach ($serviceName in $Services) {
    if (-not $serviceConfigs.ContainsKey($serviceName)) {
        Write-Host "[$serviceName] Not configured. Skipping..." -ForegroundColor Yellow
        continue
    }
    
    $config = $serviceConfigs[$serviceName]
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Processing: $($serviceName.ToUpper())" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Step 1: Get running task from ECS
    Write-Host "[1/5] Getting running tasks from cluster..." -ForegroundColor Gray
    
    $listTasksResult = aws ecs list-tasks --cluster $config.cluster --desired-status RUNNING --region $Region 2>&1 | ConvertFrom-Json
    
    if ($listTasksResult.taskArns.Count -eq 0) {
        Write-Host "  No running tasks found in cluster $($config.cluster)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Service = $serviceName.ToUpper()
            Status = "NO_TASKS"
            TaskIP = "N/A"
            Action = "Skipped"
        }
        Write-Host ""
        continue
    }
    
    # Get details of first running task
    $taskArn = $listTasksResult.taskArns[0]
    $taskId = $taskArn.Split('/')[-1].Substring(0, 8)
    
    $taskDetails = aws ecs describe-tasks --cluster $config.cluster --tasks $taskArn --region $Region 2>&1 | ConvertFrom-Json
    $task = $taskDetails.tasks[0]
    
    if ($task.lastStatus -ne "RUNNING") {
        Write-Host "  Task $taskId is not RUNNING (status: $($task.lastStatus))" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Service = $serviceName.ToUpper()
            Status = $task.lastStatus
            TaskIP = "N/A"
            Action = "Skipped"
        }
        Write-Host ""
        continue
    }
    
    # Extract task IP
    $taskIp = $null
    foreach ($attachment in $task.attachments) {
        if ($attachment.type -eq "ElasticNetworkInterface") {
            foreach ($detail in $attachment.details) {
                if ($detail.name -eq "privateIPv4Address") {
                    $taskIp = $detail.value
                    break
                }
            }
        }
    }
    
    if (-not $taskIp) {
        Write-Host "  Could not extract IP from task $taskId" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Service = $serviceName.ToUpper()
            Status = "NO_IP"
            TaskIP = "N/A"
            Action = "Skipped"
        }
        Write-Host ""
        continue
    }
    
    Write-Host "  Found running task: $taskId" -ForegroundColor Green
    Write-Host "  Task IP: $taskIp" -ForegroundColor Green
    
    # Determine which target group ARNs to sync to
    $targetGroupArnsToSync = @()
    if ($null -ne $config.targetGroupArns) {
        $targetGroupArnsToSync = $config.targetGroupArns
        Write-Host "  Using multiple target groups" -ForegroundColor Gray
    } elseif ($null -ne $config.targetGroupArn) {
        $targetGroupArnsToSync = @($config.targetGroupArn)
        Write-Host "  Using single target group" -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: No target group configured for service $serviceName" -ForegroundColor Red
        continue
    }
    
    Write-Host "  Syncing to $($targetGroupArnsToSync.Count) target group(s)" -ForegroundColor Gray
    
    # Step 2-4: Process each target group
    $tgIndex = 0
    foreach ($targetGroupArn in $targetGroupArnsToSync) {
        $tgIndex++
        $tgName = $targetGroupArn.Split('/')[-2]
        Write-Host "[2-4/$($targetGroupArnsToSync.Count)] Processing target group: $tgName ($tgIndex/$($targetGroupArnsToSync.Count))" -ForegroundColor Gray
        
        # Step 2: Check current target group state
        Write-Host "  [2/4] Checking target group..." -ForegroundColor Gray
        
        $targetHealth = aws elbv2 describe-target-health --target-group-arn $targetGroupArn --region $Region 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ERROR: Failed to describe target health" -ForegroundColor Red
            Write-Host "    AWS Error: $targetHealth" -ForegroundColor Red
            continue
        }
        
        $targetHealthJson = $targetHealth | ConvertFrom-Json
        $currentTargets = $targetHealthJson.TargetHealthDescriptions
        
        Write-Host "    Current targets in group: $($currentTargets.Count)" -ForegroundColor Gray
        
        # Step 3: Remove unhealthy or wrong targets
        Write-Host "  [3/4] Cleaning up target group..." -ForegroundColor Gray
        
        $deregistered = 0
        $drainingCount = 0
        
        foreach ($target in $currentTargets) {
            $targetIp = $target.Target.Id
            $targetPort = $target.Target.Port
            $targetState = $target.TargetHealth.State
            
            # Skip targets already draining
            if ($targetState -eq "draining") {
                Write-Host "    Target $targetIp`:$targetPort is draining (waiting...)" -ForegroundColor Gray
                $drainingCount++
                continue
            }
            
            $shouldRemove = $false
            $reason = ""
            
            # Remove if unhealthy
            if ($targetState -eq "unhealthy") {
                $shouldRemove = $true
                $reason = "unhealthy"
            }
            # Remove if wrong IP
            elseif ($targetIp -ne $taskIp) {
                $shouldRemove = $true
                $reason = "wrong IP ($targetIp vs $taskIp)"
            }
            # Remove if wrong port
            elseif ($targetPort -ne $config.port) {
                $shouldRemove = $true
                $reason = "wrong port ($targetPort vs $($config.port))"
            }
            
            if ($shouldRemove) {
                Write-Host "    Removing target $targetIp`:$targetPort ($reason)" -ForegroundColor Yellow
                aws elbv2 deregister-targets --target-group-arn $targetGroupArn --targets Id=$targetIp,Port=$targetPort --region $Region 2>&1 | Out-Null
                $deregistered++
            } else {
                Write-Host "    Target $targetIp`:$targetPort is $targetState (keeping)" -ForegroundColor Green
            }
        }
        
        if ($deregistered -eq 0 -and $drainingCount -eq 0) {
            Write-Host "    No targets to remove" -ForegroundColor Gray
        } elseif ($drainingCount -gt 0) {
            Write-Host "    Note: $drainingCount target(s) still draining (will auto-remove)" -ForegroundColor Cyan
        }
        
        # Step 4: Register correct target if not already there
        Write-Host "  [4/4] Ensuring correct target is registered..." -ForegroundColor Gray
        
        $correctTargetExists = $false
        foreach ($target in $currentTargets) {
            # Only count non-draining targets
            if ($target.Target.Id -eq $taskIp -and $target.Target.Port -eq $config.port -and $target.TargetHealth.State -ne "draining") {
                $correctTargetExists = $true
                Write-Host "    Correct target already registered (state: $($target.TargetHealth.State))" -ForegroundColor Green
                break
            }
        }
        
        if (-not $correctTargetExists) {
            Write-Host "    Registering target $taskIp`:$($config.port)" -ForegroundColor Cyan
            aws elbv2 register-targets --target-group-arn $targetGroupArn --targets Id=$taskIp,Port=$($config.port) --region $Region 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    Successfully registered!" -ForegroundColor Green
            } else {
                Write-Host "    Failed to register" -ForegroundColor Red
            }
        }
    }
    
    $results += [PSCustomObject]@{
        Service = $serviceName.ToUpper()
        Status = "SYNCED"
        TaskIP = $taskIp
        Action = "Multi-TG sync"
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Green
Write-Host "Summary" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$results | Format-Table -AutoSize

$syncedCount = ($results | Where-Object { $_.Status -eq "SYNCED" }).Count
Write-Host ""
Write-Host "Synced: $syncedCount / $($Services.Count)" -ForegroundColor $(if ($syncedCount -eq $Services.Count) { "Green" } else { "Yellow" })
Write-Host ""
Write-Host "Check status with: .\check-status.ps1" -ForegroundColor Gray
Write-Host ""

