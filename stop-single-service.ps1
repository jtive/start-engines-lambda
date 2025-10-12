# Stop a Single ECS Service
# Invokes the stop-engines-lambda for a specific service

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("auth", "pdf", "fa", "users", "batch")]
    [string]$Service,
    
    [string]$Environment = "dev",
    [string]$Region = "us-east-2",
    [bool]$DeregisterTargets = $true,
    [switch]$Force  # Skip confirmation
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Red
Write-Host "Stop ECS Service: $Service" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Deregister Targets: $DeregisterTargets" -ForegroundColor Yellow
Write-Host ""

# Confirmation prompt (unless -Force is used)
if (-not $Force) {
    $confirmation = Read-Host "Are you sure you want to stop the $Service service? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

try {
    Write-Host "Stopping service..." -ForegroundColor Cyan
    
    # Create Lambda payload
    $payload = @{
        source = "custom.app"
        "detail-type" = "Stop ECS Tasks"
        detail = @{
            services = @($Service)
            deregister_targets = $DeregisterTargets
        }
    } | ConvertTo-Json -Depth 3 -Compress
    
    # Create temp files
    $tempPayload = [System.IO.Path]::GetTempFileName()
    $payload | Out-File -FilePath $tempPayload -Encoding utf8 -NoNewline
    
    $tempResponse = [System.IO.Path]::GetTempFileName()
    
    # Invoke Lambda
    $output = aws lambda invoke `
        --function-name "stop-engines-lambda-$Environment" `
        --payload "file://$tempPayload" `
        --region $Region `
        --cli-binary-format raw-in-base64-out `
        $tempResponse 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Lambda invocation failed" -ForegroundColor Red
        Write-Host "Error: $output" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Lambda invoked successfully" -ForegroundColor Green
    Write-Host ""
    
    # Parse response
    $response = Get-Content $tempResponse -Raw | ConvertFrom-Json
    
    if ($response.body) {
        $body = $response.body | ConvertFrom-Json
        
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Results" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        
        $result = $body.results | Where-Object { $_.service -eq $Service } | Select-Object -First 1
        
        if ($result) {
            Write-Host "Service: $($result.service)" -ForegroundColor Yellow
            Write-Host "Cluster: $($result.cluster)" -ForegroundColor Yellow
            Write-Host "Tasks Stopped: $($result.tasks_stopped)" -ForegroundColor Green
            Write-Host "Targets Deregistered: $($result.targets_deregistered)" -ForegroundColor Green
            Write-Host "Status: $($result.status)" -ForegroundColor $(if ($result.status -eq "success") { "Green" } else { "Yellow" })
            
            if ($result.task_ids) {
                Write-Host ""
                Write-Host "Stopped Task IDs:" -ForegroundColor Cyan
                $result.task_ids | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
            }
        }
        
        Write-Host ""
        Write-Host "✓ Operation completed" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Lambda execution error" -ForegroundColor Red
        if ($response.errorMessage) {
            Write-Host "Error: $($response.errorMessage)" -ForegroundColor Red
        }
        exit 1
    }
    
    # Cleanup
    Remove-Item $tempPayload -ErrorAction SilentlyContinue
    Remove-Item $tempResponse -ErrorAction SilentlyContinue
    
    exit 0
}
catch {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

