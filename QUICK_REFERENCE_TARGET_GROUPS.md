# Target Group Scripts - Quick Reference

## The Problem

`start-all-services.ps1` can have a race condition where target groups are updated before tasks are fully ready.

## The Solution

Use `verify-and-update-target-groups.ps1` to safely verify tasks are running before updating target groups.

---

## Quick Commands

### Recommended: Safe Production Start

```powershell
# Start services
.\start-all-services.ps1 -Force

# Wait for stabilization
Start-Sleep -Seconds 60

# Verify and update target groups
.\verify-and-update-target-groups.ps1 -Force

# Check final status
.\check-status.ps1
```

### Quick Development Start

```powershell
# Start and verify (skip health check wait)
.\start-all-services.ps1 -Force
.\verify-and-update-target-groups.ps1 -SkipHealthCheck -Force
```

### Fix Broken Target Groups

```powershell
# Just fix target groups for running tasks
.\verify-and-update-target-groups.ps1 -Force
```

### Single Service Recovery

```powershell
# Fix one service
.\verify-and-update-target-groups.ps1 -Services pdf -Force
```

---

## Parameters Cheat Sheet

### verify-and-update-target-groups.ps1

```powershell
-Environment "dev"              # Environment name
-Region "us-east-2"             # AWS region
-Services auth,pdf,fa           # Specific services
-MaxWaitSeconds 300             # Wait time for RUNNING state (default: 5 min)
-HealthCheckWaitSeconds 120     # Wait time for healthy (default: 2 min)
-SkipHealthCheck                # Don't wait for health checks
-Force                          # Skip confirmation prompt
```

**Examples:**
```powershell
# Production with longer timeouts
.\verify-and-update-target-groups.ps1 -Environment prod -MaxWaitSeconds 600

# Just auth and pdf, no health wait
.\verify-and-update-target-groups.ps1 -Services auth,pdf -SkipHealthCheck

# All defaults with auto-confirm
.\verify-and-update-target-groups.ps1 -Force
```

---

## What Each Script Does

| Script | Purpose | Safe to Re-run? |
|--------|---------|----------------|
| `start-all-services.ps1` | Invokes Lambda to start new tasks | ❌ No (starts new tasks) |
| `verify-and-update-target-groups.ps1` | Verifies running tasks & fixes TGs | ✅ Yes (idempotent) |
| `check-status.ps1` | Shows current state | ✅ Yes (read-only) |

---

## Common Scenarios

### Scenario 1: Services Started But Not Healthy

**Symptoms:**
- `check-status.ps1` shows "Running (Unhealthy)"
- Target groups have no healthy targets

**Solution:**
```powershell
.\verify-and-update-target-groups.ps1 -Force
```

### Scenario 2: Partial Start Failure

**Symptoms:**
- Some services started, others failed
- Mixed results in summary

**Solution:**
```powershell
# Just fix the ones that are running
.\verify-and-update-target-groups.ps1 -Force

# Or start failed ones individually
.\start-single-service.ps1 -Service fa
.\verify-and-update-target-groups.ps1 -Services fa -Force
```

### Scenario 3: Tasks Running But TG Registration Failed

**Symptoms:**
- ECS shows tasks RUNNING
- Target groups empty or have wrong IPs

**Solution:**
```powershell
.\verify-and-update-target-groups.ps1 -Force
```

### Scenario 4: Need to Re-register Existing Tasks

**Symptoms:**
- Tasks running but target groups were manually modified
- Need to reset to correct state

**Solution:**
```powershell
.\verify-and-update-target-groups.ps1 -Force
```

---

## Status Indicators

### ✅ Good States
- `REGISTERED` - Target successfully registered
- `ALREADY_HEALTHY` - Target was already healthy, no action needed
- Task status: `RUNNING`
- Target health: `healthy`

### ⏳ Waiting States
- Task status: `PROVISIONING`, `PENDING`, `ACTIVATING`
- Target health: `initial`

### ❌ Problem States
- `FAILED` - Registration failed
- `ERROR` - Unexpected error occurred
- `TIMEOUT` - Task didn't start within timeout
- `STOPPED` - Task stopped/crashed
- Task status: `STOPPED`, `DEACTIVATING`
- Target health: `unhealthy`, `unavailable`

### ⚠️ Warning States
- `SKIPPED` - Service not configured or file missing
- Target health: `draining`, `unused`

---

## Troubleshooting Quick Checks

### Task Won't Start
```powershell
# Check ECS task logs
aws ecs describe-tasks --cluster authapi-cluster --tasks <task-id>
aws logs tail /ecs/authapi --follow
```

### Target Won't Become Healthy
```powershell
# Check target group health
aws elbv2 describe-target-health --target-group-arn <arn>

# Test endpoint directly
curl http://<task-ip>:<port>/health
```

### Wrong IP Registered
```powershell
# Re-run verification (it will fix it)
.\verify-and-update-target-groups.ps1 -Force
```

---

## Decision Flow

```
Need to start services?
├─ Yes → Use start-all-services.ps1
│   └─ Then wait 60s and run verify-and-update-target-groups.ps1
│
└─ No, just fix target groups?
    └─ Use verify-and-update-target-groups.ps1 directly

Services partially working?
├─ Some started → verify-and-update-target-groups.ps1
│
└─ None started → start-all-services.ps1, then verify

Production deployment?
└─ Always use both scripts in sequence

Development/Testing?
└─ Either script, or both with -SkipHealthCheck
```

---

## Timing Guide

| Operation | Typical Duration | Max Timeout |
|-----------|-----------------|-------------|
| Task PROVISIONING → RUNNING | 30-90 seconds | 5 minutes |
| Target initial → healthy | 30-60 seconds | 2 minutes |
| Full start + verification | 2-4 minutes | 7 minutes |

**Total Recommended Time:**
- Development: ~3 minutes
- Production: ~5 minutes (with longer timeouts)

---

## CI/CD Template

```yaml
# Always use this pattern in CI/CD
jobs:
  deploy:
    steps:
      - name: Start Services
        run: pwsh ./start-all-services.ps1 -Force
        
      - name: Wait for Stabilization
        run: sleep 90
        
      - name: Verify Target Groups
        run: pwsh ./verify-and-update-target-groups.ps1 -Force
        
      - name: Health Check
        run: pwsh ./check-status.ps1
        
      - name: Fail if Unhealthy
        run: |
          $status = pwsh ./check-status.ps1
          if ($status -like "*Unhealthy*") { exit 1 }
```

---

## Need More Details?

📖 See `TARGET_GROUP_VERIFICATION_GUIDE.md` for complete documentation

💡 See `README-POWERSHELL.md` for all available scripts

🔧 See `check-status.ps1` for current state

