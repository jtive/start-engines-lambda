# 🎉 New: Target Group Verification Script

## What's New

A new PowerShell script has been created to solve race condition issues with target group registration:

**`verify-and-update-target-groups.ps1`** ⭐

---

## The Problem It Solves

`start-all-services.ps1` can have a race condition where:
- Tasks are registered with target groups before they're fully ready
- Multiple concurrent starts cause timing issues
- Target groups may end up with incorrect IPs

**This new script ensures everything is verified before target groups are updated.**

---

## Quick Start

### Recommended: Use Both Scripts Together

```powershell
# 1. Start all services
.\start-all-services.ps1 -Force

# 2. Wait for tasks to stabilize
Start-Sleep -Seconds 60

# 3. Verify and update target groups
.\verify-and-update-target-groups.ps1 -Force

# 4. Check final status
.\check-status.ps1
```

### Or: Fix Target Group Issues

```powershell
# If tasks are running but target groups are wrong
.\verify-and-update-target-groups.ps1 -Force
```

---

## What It Does

1. ✅ **Verifies** ECS tasks are RUNNING (polls until confirmed)
2. ✅ **Extracts** private IP addresses from running tasks
3. ✅ **Updates** target groups with correct IPs
4. ✅ **Confirms** targets become healthy (optional)
5. ✅ **Reports** detailed status for each service

---

## Key Features

- **Idempotent** - Safe to run multiple times
- **Smart** - Skips targets that are already healthy
- **Clear Output** - Color-coded status messages
- **Configurable** - Custom timeouts and options
- **Reliable** - Comprehensive error handling

---

## Documentation

| Document | Description |
|----------|-------------|
| **[TARGET_GROUP_FIX_SUMMARY.md](TARGET_GROUP_FIX_SUMMARY.md)** | 📝 Overview and quick guide |
| **[QUICK_REFERENCE_TARGET_GROUPS.md](QUICK_REFERENCE_TARGET_GROUPS.md)** | ⚡ Command cheat sheet |
| **[TARGET_GROUP_VERIFICATION_GUIDE.md](TARGET_GROUP_VERIFICATION_GUIDE.md)** | 📖 Complete documentation |
| **[EXAMPLE_VERIFY_OUTPUT.md](EXAMPLE_VERIFY_OUTPUT.md)** | 💻 Example outputs |

---

## Common Use Cases

### Production Deployment
```powershell
.\start-all-services.ps1 -Force
Start-Sleep -Seconds 60
.\verify-and-update-target-groups.ps1 -Force
```

### Fix Broken Target Groups
```powershell
.\verify-and-update-target-groups.ps1 -Force
```

### Quick Development Start
```powershell
.\start-all-services.ps1 -Force
.\verify-and-update-target-groups.ps1 -SkipHealthCheck -Force
```

### Single Service Recovery
```powershell
.\verify-and-update-target-groups.ps1 -Services pdf -Force
```

---

## Options

```powershell
-Services auth,pdf,fa       # Specific services (default: all)
-MaxWaitSeconds 600         # Wait time for RUNNING (default: 300)
-HealthCheckWaitSeconds 180 # Wait for healthy (default: 120)
-SkipHealthCheck            # Don't wait for health checks
-Force                      # Skip confirmation prompt
-Environment prod           # Environment name (default: dev)
-Region us-west-2           # AWS region (default: us-east-2)
```

---

## When to Use

| Scenario | Script to Use |
|----------|---------------|
| Starting services from stopped | `start-all-services.ps1` → `verify-and-update-target-groups.ps1` |
| Tasks running but TGs wrong | `verify-and-update-target-groups.ps1` |
| Production deployments | Both scripts in sequence |
| Verifying current state | `verify-and-update-target-groups.ps1` |
| Quick dev start | Both scripts (with `-SkipHealthCheck`) |

---

## Benefits

✅ **Eliminates race conditions** - Verifies before updating  
✅ **Safer deployments** - Confirms everything is correct  
✅ **Better visibility** - Clear status reporting  
✅ **Error recovery** - Fixes issues automatically  
✅ **Production-ready** - Comprehensive error handling  

---

## Example Output

```
========================================
Phase 1: Verify Tasks are RUNNING
========================================

Checking auth tasks...
  Cluster: authapi-cluster
  ✅ Task is RUNNING
     Task ID: a1b2c3d4e5f67890
     Private IP: 10.0.1.123

========================================
Phase 2: Register Tasks with Target Groups
========================================

Registering auth with target group...
  IP: 10.0.1.123:8080
  Target Group: unified-auth-tg
  ✅ Successfully registered with target group

========================================
Phase 3: Verify Target Health
========================================

  ✅ auth is healthy

🎉 All targets are healthy!

========================================
Summary
========================================

Service Status      Message
------- ------      -------
AUTH    REGISTERED  Target registered successfully

✅ All services verified and registered: 1 / 1
```

---

## Need More Info?

- 📖 **Full Guide**: [TARGET_GROUP_VERIFICATION_GUIDE.md](TARGET_GROUP_VERIFICATION_GUIDE.md)
- ⚡ **Quick Ref**: [QUICK_REFERENCE_TARGET_GROUPS.md](QUICK_REFERENCE_TARGET_GROUPS.md)
- 📝 **Summary**: [TARGET_GROUP_FIX_SUMMARY.md](TARGET_GROUP_FIX_SUMMARY.md)
- 📚 **All Scripts**: [README-POWERSHELL.md](README-POWERSHELL.md)

---

**🚀 Ready to use! Just run `.\verify-and-update-target-groups.ps1`**

