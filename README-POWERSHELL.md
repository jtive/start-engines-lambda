# PowerShell Scripts Guide

## 📋 Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **start-all-services.ps1** | Start all ECS services | `.\start-all-services.ps1` |
| **stop-all-services.ps1** | Stop all ECS services | `.\stop-all-services.ps1` |
| **start-single-service.ps1** | Start a single service | `.\start-single-service.ps1 -Service auth` |
| **stop-single-service.ps1** | Stop a single service | `.\stop-single-service.ps1 -Service auth` |
| **check-services-status.ps1** | Check status of all services | `.\check-services-status.ps1` |

---

## 🚀 Quick Start

### 1. Start All Services
```powershell
# Start all 5 services
.\start-all-services.ps1

# Start specific services only
.\start-all-services.ps1 -Services @("auth", "pdf")

# Use different region
.\start-all-services.ps1 -Region us-west-2
```

### 2. Stop All Services
```powershell
# Stop all services (with confirmation)
.\stop-all-services.ps1

# Stop all services (skip confirmation)
.\stop-all-services.ps1 -Force

# Stop specific services only
.\stop-all-services.ps1 -Services @("auth", "pdf")

# Stop without deregistering from target groups
.\stop-all-services.ps1 -DeregisterTargets $false
```

### 3. Start Single Service
```powershell
# Start the auth service
.\start-single-service.ps1 -Service auth

# Start the PDF service
.\start-single-service.ps1 -Service pdf

# Available services: auth, pdf, fa, users, batch
```

### 4. Stop Single Service
```powershell
# Stop the auth service (with confirmation)
.\stop-single-service.ps1 -Service auth

# Stop the auth service (skip confirmation)
.\stop-single-service.ps1 -Service auth -Force

# Stop without deregistering
.\stop-single-service.ps1 -Service auth -DeregisterTargets $false
```

### 5. Check Services Status
```powershell
# Check status of all services
.\check-services-status.ps1

# Check status in different region
.\check-services-status.ps1 -Region us-west-2
```

---

## 📊 Script Parameters

### start-all-services.ps1
```powershell
.\start-all-services.ps1 `
    -Environment "dev" `             # Environment name (default: dev)
    -Region "us-east-2" `            # AWS region (default: us-east-2)
    -Services @("auth", "pdf")       # Services to start (default: all)
```

### stop-all-services.ps1
```powershell
.\stop-all-services.ps1 `
    -Environment "dev" `             # Environment name (default: dev)
    -Region "us-east-2" `            # AWS region (default: us-east-2)
    -Services @("auth", "pdf") `     # Services to stop (default: all)
    -DeregisterTargets $true `       # Deregister from target groups (default: true)
    -Force                           # Skip confirmation prompt
```

### start-single-service.ps1
```powershell
.\start-single-service.ps1 `
    -Service "auth" `                # Service to start (required)
    -Environment "dev" `             # Environment name (default: dev)
    -Region "us-east-2"              # AWS region (default: us-east-2)
```

### stop-single-service.ps1
```powershell
.\stop-single-service.ps1 `
    -Service "auth" `                # Service to stop (required)
    -Environment "dev" `             # Environment name (default: dev)
    -Region "us-east-2" `            # AWS region (default: us-east-2)
    -DeregisterTargets $true `       # Deregister from target groups (default: true)
    -Force                           # Skip confirmation prompt
```

### check-services-status.ps1
```powershell
.\check-services-status.ps1 `
    -Region "us-east-2" `            # AWS region (default: us-east-2)
    -Environment "dev"               # Environment name (default: dev)
```

---

## 🎯 Common Workflows

### Daily Development Workflow
```powershell
# Morning: Check status, then start all services
.\check-services-status.ps1
.\start-all-services.ps1

# Evening: Stop all services to save costs
.\stop-all-services.ps1 -Force
```

### Restart All Services
```powershell
# Stop all
.\stop-all-services.ps1 -Force

# Wait 30 seconds
Start-Sleep -Seconds 30

# Start all
.\start-all-services.ps1
```

### Test Single Service
```powershell
# Stop just the auth service
.\stop-single-service.ps1 -Service auth -Force

# Make code changes, rebuild, deploy

# Start the auth service
.\start-single-service.ps1 -Service auth

# Check status
.\check-services-status.ps1
```

---

## 🔍 Output Examples

### start-all-services.ps1 Output
```
========================================
Starting All ECS Services
========================================
Environment: dev
Region: us-east-2
Services: auth, pdf, fa, users, batch

[auth] Starting...
[auth] ✓ Event sent successfully
[pdf] Starting...
[pdf] ✓ Event sent successfully
[fa] Starting...
[fa] ✓ Event sent successfully
[users] Starting...
[users] ✓ Event sent successfully
[batch] Starting...
[batch] ✓ Event sent successfully

========================================
Summary
========================================
Success: 5
Failed: 0

Service    Status      Result
-------    ------      ------
auth       Event Sent  Success
pdf        Event Sent  Success
fa         Event Sent  Success
users      Event Sent  Success
batch      Event Sent  Success

✓ All services started successfully!
```

### stop-all-services.ps1 Output
```
========================================
Stop All ECS Services
========================================
Environment: dev
Region: us-east-2
Services: ALL
Deregister Targets: True

Are you sure you want to stop all services? (yes/no): yes
Stopping all ECS tasks...

Invoking Lambda function...
✓ Lambda invoked successfully

========================================
Results
========================================
Message: Successfully stopped 5 tasks across 5 services
Total Tasks Stopped: 5
Services Processed: 5

Detailed Results:

Service    Cluster         TasksStopped    TargetsDeregistered    Status
-------    -------         ------------    -------------------    ------
auth       auth-cluster    1               1                      success
pdf        pdf-cluster     1               1                      success
fa         fa-cluster      1               1                      success
users      users-cluster   1               1                      success
batch      batch-cluster   1               1                      success

✓ Operation completed successfully
```

### check-services-status.ps1 Output
```
========================================
ECS Services Status Check
========================================
Region: us-east-2
Environment: dev

Checking auth...
Checking pdf...
Checking fa...
Checking users...
Checking batch...

========================================
Services Summary
========================================

Service    Cluster         RunningTasks    HealthyTargets    UnhealthyTargets    Port    Status
-------    -------         ------------    --------------    ----------------    ----    ------
AUTH       auth-cluster    1               1                 0                   8080    Running & Healthy
BATCH      batch-cluster   0               0                 0                   8080    Stopped
FA         fa-cluster      1               1                 0                   2531    Running & Healthy
PDF        pdf-cluster     1               0                 1                   9080    Running (Unhealthy)
USERS      users-cluster   0               0                 0                   8080    Stopped

Total Services Running: 3
Total Services Stopped: 2
Total Healthy Targets: 2
```

---

## ⚙️ Prerequisites

1. **AWS CLI** installed and configured
   ```powershell
   aws --version
   aws configure
   ```

2. **PowerShell** (comes with Windows)
   ```powershell
   $PSVersionTable.PSVersion
   ```

3. **AWS Credentials** configured
   ```powershell
   aws sts get-caller-identity
   ```

4. **Lambda Functions** deployed
   - `start-engines-lambda-dev`
   - `stop-engines-lambda-dev`

---

## 🛡️ Safety Features

### Confirmation Prompts
Both stop scripts include confirmation prompts by default:
```powershell
# Will ask for confirmation
.\stop-all-services.ps1

# Skip confirmation with -Force
.\stop-all-services.ps1 -Force
```

### Error Handling
All scripts include comprehensive error handling:
- Exit codes (0 = success, 1 = error)
- Colored output (Red = error, Yellow = warning, Green = success)
- Detailed error messages

### Validation
- Service names are validated (must be: auth, pdf, fa, users, batch)
- AWS CLI availability is checked
- Lambda function existence is verified

---

## 🎨 Color Coding

| Color | Meaning |
|-------|---------|
| 🟢 **Green** | Success / Running |
| 🟡 **Yellow** | Warning / Information |
| 🔴 **Red** | Error / Stopped |
| 🔵 **Cyan** | Headers / Processing |
| ⚪ **Gray** | Details / Commands |

---

## 📝 Tips & Tricks

### Create PowerShell Aliases
Add to your PowerShell profile (`$PROFILE`):
```powershell
# Open profile
notepad $PROFILE

# Add aliases
Set-Alias start-all "D:\Dev\start-engines-lambda\start-all-services.ps1"
Set-Alias stop-all "D:\Dev\start-engines-lambda\stop-all-services.ps1"
Set-Alias check-services "D:\Dev\start-engines-lambda\check-services-status.ps1"

# Reload profile
. $PROFILE
```

### Quick Start/Stop from Anywhere
```powershell
# Create a function in your profile
function Start-ECS { 
    & "D:\Dev\start-engines-lambda\start-all-services.ps1" @args 
}

function Stop-ECS { 
    & "D:\Dev\start-engines-lambda\stop-all-services.ps1" @args 
}

# Usage
Start-ECS
Stop-ECS -Force
```

### Schedule with Task Scheduler
```powershell
# Stop nightly at 8 PM
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File D:\Dev\start-engines-lambda\stop-all-services.ps1 -Force"
$trigger = New-ScheduledTaskTrigger -Daily -At "8:00PM"
Register-ScheduledTask -TaskName "Stop ECS Services" -Action $action -Trigger $trigger

# Start daily at 8 AM
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File D:\Dev\start-engines-lambda\start-all-services.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "8:00AM"
Register-ScheduledTask -TaskName "Start ECS Services" -Action $action -Trigger $trigger
```

---

## 🐛 Troubleshooting

### Script Won't Run
**Error**: "Script execution is disabled"
```powershell
# Check execution policy
Get-ExecutionPolicy

# Allow scripts (run as Administrator)
Set-ExecutionPolicy RemoteSigned

# Or run with bypass
powershell -ExecutionPolicy Bypass -File .\start-all-services.ps1
```

### AWS CLI Not Found
```powershell
# Install AWS CLI
winget install Amazon.AWSCLI

# Or download from: https://aws.amazon.com/cli/
```

### Services Not Starting
1. Check Lambda logs
2. Verify ECS clusters exist
3. Check IAM permissions
4. Ensure task definitions are registered

---

## 📚 Additional Resources

- **[STOP_LAMBDA_GUIDE.md](STOP_LAMBDA_GUIDE.md)** - Detailed stop lambda guide
- **[START_STOP_COMPARISON.md](START_STOP_COMPARISON.md)** - Compare both lambdas
- **[COMPLETE_PROJECT_SUMMARY.md](COMPLETE_PROJECT_SUMMARY.md)** - Complete overview

---

## 💡 Examples

### Morning Routine
```powershell
# Check what's running
.\check-services-status.ps1

# Start everything
.\start-all-services.ps1

# Wait for services to be healthy
Start-Sleep -Seconds 60

# Verify
.\check-services-status.ps1
```

### Evening Routine
```powershell
# Save costs by stopping everything
.\stop-all-services.ps1 -Force

# Verify everything is stopped
.\check-services-status.ps1
```

### Debug Single Service
```powershell
# Stop the problematic service
.\stop-single-service.ps1 -Service auth -Force

# Deploy new version
# ...

# Start it back up
.\start-single-service.ps1 -Service auth

# Monitor
aws logs tail /aws/lambda/start-engines-lambda-dev --follow
```

---

**🎉 Happy scripting!**

