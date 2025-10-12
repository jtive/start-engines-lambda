# Stop All ECS Services
# Invokes the stop-engines-lambda to stop all running tasks

param(
    [string]$Environment = "dev",
    [string]$Region = "us-east-2",
    [switch]$Force  # Skip confirmation
)

Write-Host "========================================" -ForegroundColor Red
Write-Host "Stop All ECS Services" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
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

# Invoke Lambda directly
$functionName = "stop-engines-lambda-$Environment"
$payloadFile = "$PSScriptRoot\example-events\stop-all-tasks.json"
$responseFile = "$PSScriptRoot\response-stop-all.json"

Write-Host "Invoking Lambda: $functionName" -ForegroundColor Cyan

aws lambda invoke `
    --function-name $functionName `
    --payload file://$payloadFile `
    --cli-binary-format raw-in-base64-out `
    --region $Region `
    $responseFile | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "Lambda invoked successfully" -ForegroundColor Green
    Write-Host ""
    
    # Parse and display response
    $response = Get-Content $responseFile -Raw | ConvertFrom-Json
    
    if ($response.body) {
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Results" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Message: $($response.body.message)" -ForegroundColor Yellow
        Write-Host "Total Tasks Stopped: $($response.body.total_tasks_stopped)" -ForegroundColor Green
        Write-Host ""
        
        if ($response.body.results) {
            Write-Host "Service Details:" -ForegroundColor Cyan
            foreach ($result in $response.body.results) {
                $color = if ($result.status -eq "success") { "Green" } elseif ($result.status -eq "error") { "Red" } else { "Yellow" }
                Write-Host "  $($result.service.ToUpper()): $($result.tasks_stopped) tasks stopped" -ForegroundColor $color
            }
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Operation completed successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
    }
    
    # Cleanup
    Remove-Item $responseFile -ErrorAction SilentlyContinue
} else {
    Write-Host "Lambda invocation failed!" -ForegroundColor Red
    exit 1
}
