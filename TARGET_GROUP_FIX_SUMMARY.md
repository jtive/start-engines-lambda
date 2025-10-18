# Target Group Race Condition Fix - Summary

## Overview

This document summarizes the solution to the race condition bug in `start-all-services.ps1` related to target group registration.

---

## The Problem

### Issue Identified

The `start-all-services.ps1` script invokes a Lambda function that:

1. ✅ Starts ECS Fargate tasks
2. ✅ Waits for tasks to reach RUNNING state  
3. ⚠️ **Immediately registers tasks with target groups**
4. ⚠️ **No verification that registration succeeded**

**Race Conditions:**

- Multiple services starting concurrently can cause timing issues
- Network interface IP assignment may be delayed
- Lambda timeout constraints limit verification time
- PowerShell script doesn't verify Lambda success before moving to next service
- Target group health checks begin before application is ready

**Real-World Impact:**

- Tasks may be RUNNING but not yet healthy
- Target groups may have wrong IPs registered
- Services appear started but aren't receiving traffic
- Manual intervention required to fix target group state

---

## The Solution

### New Script: `verify-and-update-target-groups.ps1`

A comprehensive PowerShell script that safely verifies ECS tasks are running and correctly updates target groups.

**Key Features:**

✅ **Verification-First Approach**
- Actively polls ECS until tasks are confirmed RUNNING
- Extracts actual private IP addresses from running tasks
- Validates task state before any target group operations

✅ **Safe Target Group Updates**
- Only updates target groups after tasks are verified running
- Checks if targets are already registered
- Skips registration if targets are already healthy
- Idempotent - safe to run multiple times

✅ **Health Check Verification** (Optional)
- Waits for targets to become healthy
- Reports health check status in real-time
- Configurable timeout for health checks
- Can skip health check waiting with `-SkipHealthCheck` flag

✅ **Comprehensive Error Handling**
- Detailed error messages for each failure type
- Graceful handling of missing or stopped tasks
- Clear status reporting for each service
- Summary with success/failure counts

✅ **Production-Ready**
- Confirmation prompts (bypass with `-Force`)
- Customizable timeouts for different environments
- Colored output for easy visual parsing
- Detailed logging of all operations

---

## Files Created

### 1. `verify-and-update-target-groups.ps1` ⭐
**The main solution script**

- Verifies ECS tasks are RUNNING
- Updates target groups with correct IPs
- Optional health check verification
- Full error handling and reporting

**Usage:**
```powershell
.\verify-and-update-target-groups.ps1 -Force
```

### 2. `TARGET_GROUP_VERIFICATION_GUIDE.md` 📖
**Complete documentation** (8,000+ words)

- Detailed problem explanation
- Comprehensive usage guide
- All parameters explained
- Troubleshooting section
- Common scenarios and solutions
- ECS task state reference
- Target health state reference
- CI/CD integration examples
- Best practices

### 3. `QUICK_REFERENCE_TARGET_GROUPS.md` ⚡
**Quick reference card**

- Common commands
- Parameter cheat sheet
- Decision flow diagram
- Troubleshooting quick checks
- CI/CD template
- Timing guide

### 4. `EXAMPLE_VERIFY_OUTPUT.md` 💻
**Example outputs**

- Successful run example
- Already-healthy tasks example
- Partial failure example
- Skip health check mode
- Common error messages
- Timing information

### 5. `TARGET_GROUP_FIX_SUMMARY.md` 📝
**This document**

- Overview of the problem
- Overview of the solution
- What was created
- How to use

### 6. Updated `README-POWERSHELL.md` 📚
**Enhanced documentation**

- Added new script to available scripts table
- Warning about race condition
- New workflow: "Production Start (Recommended)"
- New workflow: "Fix Target Group Issues"
- Parameters section for new script
- Links to new documentation

---

## How to Use

### Option 1: Production Deployment (Recommended)

**When to use:** Production deployments, CI/CD pipelines, maximum reliability

```powershell
# Step 1: Start all services
.\start-all-services.ps1 -Force

# Step 2: Wait for tasks to stabilize
Start-Sleep -Seconds 60

# Step 3: Verify and update target groups
.\verify-and-update-target-groups.ps1 -Force

# Step 4: Check final status
.\check-status.ps1
```

**Why this works:**
- Lambda handles initial task creation
- Wait time allows tasks to reach RUNNING state
- Verification script ensures everything is correct
- Final check confirms all services are healthy

### Option 2: Fix Existing Issues

**When to use:** Tasks are running but target groups are wrong

```powershell
# Just run the verification script
.\verify-and-update-target-groups.ps1 -Force
```

**Why this works:**
- Script finds currently running tasks
- Updates target groups with correct IPs
- Skips already-healthy targets
- Idempotent - safe to run anytime

### Option 3: Development Quick Start

**When to use:** Development environment, speed is priority

```powershell
# Start services
.\start-all-services.ps1 -Force

# Quick verification (skip health check wait)
.\verify-and-update-target-groups.ps1 -SkipHealthCheck -Force
```

**Why this works:**
- Faster than waiting for health checks
- Still verifies tasks are RUNNING
- Still updates target groups correctly
- Health checks will complete in background

### Option 4: Individual Service Recovery

**When to use:** One service is problematic

```powershell
# Start the service
.\start-single-service.ps1 -Service pdf

# Verify just that service
.\verify-and-update-target-groups.ps1 -Services pdf -Force
```

**Why this works:**
- Focused on single service
- Faster than checking all services
- Doesn't affect other running services

---

## Script Comparison

| Feature | start-all-services.ps1 | verify-and-update-target-groups.ps1 |
|---------|------------------------|-------------------------------------|
| **Primary Purpose** | Start new ECS tasks | Verify & fix target groups |
| **Task Verification** | ❌ No (relies on Lambda) | ✅ Yes (active polling) |
| **Waits for RUNNING** | ⚠️ Lambda does, PS doesn't | ✅ Yes (with timeout) |
| **Gets Task IPs** | ❌ No | ✅ Yes (from running tasks) |
| **Target Group Update** | ⚠️ Lambda attempts | ✅ After verification |
| **Health Check Verification** | ❌ No | ✅ Yes (optional) |
| **Idempotent** | ❌ No (starts new tasks) | ✅ Yes (safe to re-run) |
| **Error Recovery** | ❌ Limited | ✅ Comprehensive |
| **Best Use Case** | Initial startup | Verification & recovery |
| **When to Use** | Starting from stopped | After start, or fixing issues |

---

## Technical Details

### Phase 1: Verify Tasks are RUNNING

```
1. List tasks in cluster with RUNNING desired status
2. Describe task details to get actual state
3. Check lastStatus field (PROVISIONING → PENDING → RUNNING)
4. Extract private IP from network interface attachment
5. Repeat until RUNNING or timeout (default: 5 minutes)
```

**Handled States:**
- `PROVISIONING` → Wait
- `PENDING` → Wait  
- `ACTIVATING` → Wait
- `RUNNING` + IP available → Success
- `STOPPED` → Report error and skip
- Timeout → Report timeout error

### Phase 2: Register with Target Groups

```
1. Check if target already registered in target group
2. If healthy, skip registration (already correct)
3. If not registered or unhealthy, register target
4. Use extracted IP and configured port
5. Handle registration errors gracefully
```

**Features:**
- Checks existing registrations first
- Prevents duplicate registrations
- Uses correct port per service
- Detailed error messages

### Phase 3: Verify Target Health (Optional)

```
1. Poll target health every 10 seconds
2. Report current state for each target
3. Exit early if all become healthy
4. Timeout after configured duration (default: 2 minutes)
5. Report final health status
```

**Target States:**
- `initial` → Waiting for first health check
- `healthy` → Passing health checks (goal)
- `unhealthy` → Failing health checks (investigate)
- `draining` → Being deregistered (wait)
- Other states → Report as warnings

---

## Configuration

### Service Configurations

The script includes service configurations that match `config.py`:

```powershell
$serviceConfigs = @{
    "auth"  = @{ cluster = "authapi-cluster"; targetGroupArn = "..."; port = 8080 }
    "pdf"   = @{ cluster = "pdfcreator-cluster"; targetGroupArn = "..."; port = 9080 }
    "fa"    = @{ cluster = "fa-engine-cluster"; targetGroupArn = "..."; port = 2531 }
    "users" = @{ cluster = "user-management-cluster"; targetGroupArn = "..."; port = 8080 }
    "batch" = @{ cluster = "batch-engine"; targetGroupArn = "..."; port = 8080 }
}
```

**Important:** Keep this in sync with your actual AWS resources!

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Environment` | `"dev"` | Environment name |
| `-Region` | `"us-east-2"` | AWS region |
| `-Services` | All 5 services | Services to process |
| `-MaxWaitSeconds` | `300` (5 min) | Wait for RUNNING state |
| `-HealthCheckWaitSeconds` | `120` (2 min) | Wait for healthy |
| `-SkipHealthCheck` | `false` | Skip health check waiting |
| `-Force` | `false` | Skip confirmation |

---

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy ECS Services

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-2
          
      - name: Start ECS Services
        run: |
          pwsh -Command ".\start-all-services.ps1 -Force"
          
      - name: Wait for Tasks to Stabilize
        run: Start-Sleep -Seconds 90
        
      - name: Verify and Update Target Groups
        run: |
          pwsh -Command ".\verify-and-update-target-groups.ps1 -Force -MaxWaitSeconds 600"
          
      - name: Verify All Services Healthy
        run: |
          pwsh -Command ".\check-status.ps1"
```

### Jenkins

```groovy
pipeline {
    agent any
    
    stages {
        stage('Start Services') {
            steps {
                powershell './start-all-services.ps1 -Force'
            }
        }
        
        stage('Wait for Stabilization') {
            steps {
                sleep time: 90, unit: 'SECONDS'
            }
        }
        
        stage('Verify Target Groups') {
            steps {
                powershell './verify-and-update-target-groups.ps1 -Force'
            }
        }
        
        stage('Health Check') {
            steps {
                powershell './check-status.ps1'
            }
        }
    }
}
```

---

## Troubleshooting

### Script Reports "TIMEOUT"

**Cause:** Task didn't reach RUNNING state within timeout

**Solutions:**
1. Increase timeout: `-MaxWaitSeconds 600`
2. Check ECS task logs for startup issues
3. Verify task definition is correct
4. Check if cluster has capacity

### Target Shows "unhealthy"

**Cause:** Application not responding to health checks

**Solutions:**
1. Check target group health check configuration
2. Verify application is listening on correct port
3. Check security groups allow ALB → Task traffic
4. Review application logs for errors
5. Test endpoint directly: `curl http://<task-ip>:<port>/health`

### "Target already registered" Warning

**This is normal and good!** The script detected existing registration and will verify it's correct.

If target is already healthy, script skips registration (optimal behavior).

### Tasks Won't Start

**This is an ECS issue, not a script issue.**

**Solutions:**
1. Check ECS console for task failures
2. Review CloudWatch logs for task
3. Verify task definition is valid
4. Check IAM roles and permissions
5. Ensure container images are accessible

---

## Best Practices

### 1. Always Use in Production

```powershell
# Production deployment pattern
.\start-all-services.ps1 -Environment prod -Force
Start-Sleep -Seconds 90
.\verify-and-update-target-groups.ps1 -Environment prod -Force -MaxWaitSeconds 600
.\check-status.ps1 -Environment prod
```

### 2. Use Appropriate Timeouts

- **Development:** Default timeouts (fast feedback)
- **Production:** Longer timeouts (reliability)

```powershell
# Production with longer timeouts
.\verify-and-update-target-groups.ps1 -MaxWaitSeconds 600 -HealthCheckWaitSeconds 300
```

### 3. Monitor Output

- Don't ignore yellow warnings
- Check CloudWatch logs for errors
- Verify final health status

### 4. Keep Configuration Synchronized

- Update PowerShell configs when AWS resources change
- Verify target group ARNs are correct
- Ensure cluster names match

### 5. Document Your Process

- Add to deployment runbooks
- Train team on both scripts
- Keep this guide accessible

---

## Benefits

### Reliability
- ✅ Eliminates race conditions
- ✅ Verifies tasks are actually running
- ✅ Ensures target groups are correct
- ✅ Confirms health checks pass

### Visibility
- ✅ Clear status reporting
- ✅ Detailed error messages
- ✅ Real-time progress updates
- ✅ Color-coded output

### Safety
- ✅ Idempotent (safe to re-run)
- ✅ Confirmation prompts
- ✅ No destructive operations
- ✅ Comprehensive error handling

### Maintainability
- ✅ Well-documented
- ✅ Clear code structure
- ✅ Extensive inline comments
- ✅ Multiple guide documents

---

## Summary

The `verify-and-update-target-groups.ps1` script solves the race condition in `start-all-services.ps1` by:

1. **Verifying** tasks are actually RUNNING before any target group operations
2. **Extracting** correct private IPs from running tasks
3. **Updating** target groups only with verified information
4. **Confirming** targets become healthy (optional)
5. **Reporting** detailed status and errors

**Use it:**
- ✅ After starting services (production pattern)
- ✅ To fix target group issues
- ✅ For verification and peace of mind
- ✅ In CI/CD pipelines

**Key Advantage:**
The script is **idempotent** - you can run it as many times as needed without causing problems. It will check the current state and only make necessary changes.

---

## Quick Links

- 📖 [Complete Guide](TARGET_GROUP_VERIFICATION_GUIDE.md) - Full documentation
- ⚡ [Quick Reference](QUICK_REFERENCE_TARGET_GROUPS.md) - Command cheat sheet  
- 💻 [Example Output](EXAMPLE_VERIFY_OUTPUT.md) - See what to expect
- 📚 [PowerShell Guide](README-POWERSHELL.md) - All PowerShell scripts

---

## Support

If you encounter issues:

1. ✅ Check the [TARGET_GROUP_VERIFICATION_GUIDE.md](TARGET_GROUP_VERIFICATION_GUIDE.md)
2. ✅ Review [EXAMPLE_VERIFY_OUTPUT.md](EXAMPLE_VERIFY_OUTPUT.md) for similar errors
3. ✅ Run `.\check-status.ps1` to see current state
4. ✅ Check CloudWatch logs for tasks
5. ✅ Verify AWS Console for task/target group status

---

**🎉 You now have a reliable solution for managing ECS task startup and target group registration!**

