# Start a Single ECS Service
# Triggers the start-engines-lambda for a specific service

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("auth", "pdf", "fa", "users", "batch")]
    [string]$Service,
    
    [string]$Environment = "dev",
    [string]$Region = "us-east-2"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Green
Write-Host "Start ECS Service: $Service" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "Sending start event..." -ForegroundColor Cyan
    
    # Create event payload
    $event = @{
        Source = "custom.app"
        DetailType = "Start ECS Task"
        Detail = "{`"service`":`"$Service`"}"
    } | ConvertTo-Json -Compress
    
    # Send event to EventBridge
    $output = aws events put-events `
        --entries "[$event]" `
        --region $Region 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to send event" -ForegroundColor Red
        Write-Host "Error: $output" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Event sent successfully" -ForegroundColor Green
    Write-Host ""
    
    # Determine cluster name
    $cluster = switch ($Service) {
        "auth" { "auth-cluster" }
        "pdf" { "pdf-cluster" }
        "fa" { "fa-cluster" }
        "users" { "users-cluster" }
        "batch" { "batch-cluster" }
    }
    
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Next Steps" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "1. Monitor Lambda logs:" -ForegroundColor Yellow
    Write-Host "   aws logs tail /aws/lambda/start-engines-lambda-$Environment --follow --region $Region" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Check task status (wait 30-60 seconds):" -ForegroundColor Yellow
    Write-Host "   aws ecs list-tasks --cluster $cluster --desired-status RUNNING --region $Region" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Verify target health:" -ForegroundColor Yellow
    Write-Host "   aws elbv2 describe-target-health --target-group-arn <your-target-group-arn> --region $Region" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "✓ Service start initiated: $Service" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

