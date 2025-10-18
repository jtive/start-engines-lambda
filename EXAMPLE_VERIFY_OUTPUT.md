# Example Output: verify-and-update-target-groups.ps1

## Successful Run

```powershell
PS G:\Dev\start-engines-lambda> .\verify-and-update-target-groups.ps1 -Force

========================================
Verify ECS Tasks & Update Target Groups
========================================
Environment: dev
Region: us-east-2
Services: auth, pdf, fa, users, batch
Max Wait: 300 seconds


========================================
Phase 1: Verify Tasks are RUNNING
========================================

Checking auth tasks...
  Cluster: authapi-cluster
  ⏳ No running tasks yet. Waiting...
  ⏳ Task status: PROVISIONING. Waiting...
  ⏳ Task status: PENDING. Waiting...
  ✅ Task is RUNNING
     Task ID: a1b2c3d4e5f67890
     Private IP: 10.0.1.123

Checking pdf tasks...
  Cluster: pdfcreator-cluster
  ✅ Task is RUNNING
     Task ID: b2c3d4e5f6789012
     Private IP: 10.0.1.124

Checking fa tasks...
  Cluster: fa-engine-cluster
  ✅ Task is RUNNING
     Task ID: c3d4e5f678901234
     Private IP: 10.0.1.125

Checking users tasks...
  Cluster: user-management-cluster
  ✅ Task is RUNNING
     Task ID: d4e5f67890123456
     Private IP: 10.0.1.126

Checking batch tasks...
  Cluster: batch-engine
  ✅ Task is RUNNING
     Task ID: e5f6789012345678
     Private IP: 10.0.1.127


========================================
Phase 2: Register Tasks with Target Groups
========================================

Registering auth with target group...
  IP: 10.0.1.123:8080
  Target Group: unified-auth-tg
  ℹ️  Target already registered. Current state: initial
  ✅ Successfully registered with target group

Registering pdf with target group...
  IP: 10.0.1.124:9080
  Target Group: unified-pdf-tg
  ✅ Successfully registered with target group

Registering fa with target group...
  IP: 10.0.1.125:2531
  Target Group: unified-fa-tg
  ✅ Successfully registered with target group

Registering users with target group...
  IP: 10.0.1.126:8080
  Target Group: users-tg
  ✅ Successfully registered with target group

Registering batch with target group...
  IP: 10.0.1.127:8080
  Target Group: batch-tg
  ✅ Successfully registered with target group


========================================
Phase 3: Verify Target Health
========================================

Waiting up to 120 seconds for targets to become healthy...

  ⏳ auth is initial
  ⏳ pdf is initial
  ⏳ fa is initial
  ⏳ users is initial
  ⏳ batch is initial

  Checking again in 10 seconds... (110 seconds remaining)

  ✅ auth is healthy
  ⏳ pdf is initial
  ⏳ fa is initial
  ⏳ users is initial
  ⏳ batch is initial

  Checking again in 10 seconds... (100 seconds remaining)

  ✅ auth is healthy
  ✅ pdf is healthy
  ✅ fa is healthy
  ⏳ users is initial
  ⏳ batch is initial

  Checking again in 10 seconds... (90 seconds remaining)

  ✅ auth is healthy
  ✅ pdf is healthy
  ✅ fa is healthy
  ✅ users is healthy
  ✅ batch is healthy

🎉 All targets are healthy!


========================================
Summary
========================================

Service Status        Message                          TaskIP
------- ------        -------                          ------
AUTH    REGISTERED    Target registered successfully   10.0.1.123
PDF     REGISTERED    Target registered successfully   10.0.1.124
FA      REGISTERED    Target registered successfully   10.0.1.125
USERS   REGISTERED    Target registered successfully   10.0.1.126
BATCH   REGISTERED    Target registered successfully   10.0.1.127


✅ All services verified and registered: 5 / 5

Check current status with:
  .\check-status.ps1

```

---

## Run with Existing Healthy Tasks

```powershell
PS G:\Dev\start-engines-lambda> .\verify-and-update-target-groups.ps1 -Force

========================================
Verify ECS Tasks & Update Target Groups
========================================
Environment: dev
Region: us-east-2
Services: auth, pdf, fa, users, batch
Max Wait: 300 seconds


========================================
Phase 1: Verify Tasks are RUNNING
========================================

Checking auth tasks...
  Cluster: authapi-cluster
  ✅ Task is RUNNING
     Task ID: a1b2c3d4e5f67890
     Private IP: 10.0.1.123

Checking pdf tasks...
  Cluster: pdfcreator-cluster
  ✅ Task is RUNNING
     Task ID: b2c3d4e5f6789012
     Private IP: 10.0.1.124

[... other services ...]


========================================
Phase 2: Register Tasks with Target Groups
========================================

Registering auth with target group...
  IP: 10.0.1.123:8080
  Target Group: unified-auth-tg
  ℹ️  Target already registered. Current state: healthy
  ✅ Target already healthy. Skipping registration.

Registering pdf with target group...
  IP: 10.0.1.124:9080
  Target Group: unified-pdf-tg
  ℹ️  Target already registered. Current state: healthy
  ✅ Target already healthy. Skipping registration.

[... other services ...]


========================================
Summary
========================================

Service Status           Message                           TaskIP
------- ------           -------                           ------
AUTH    ALREADY_HEALTHY  Already registered and healthy    10.0.1.123
PDF     ALREADY_HEALTHY  Already registered and healthy    10.0.1.124
FA      ALREADY_HEALTHY  Already registered and healthy    10.0.1.125
USERS   ALREADY_HEALTHY  Already registered and healthy    10.0.1.126
BATCH   ALREADY_HEALTHY  Already registered and healthy    10.0.1.127


✅ All services verified and registered: 5 / 5

Check current status with:
  .\check-status.ps1

```

---

## With Failures

```powershell
PS G:\Dev\start-engines-lambda> .\verify-and-update-target-groups.ps1 -Services auth,pdf,users

========================================
Verify ECS Tasks & Update Target Groups
========================================
Environment: dev
Region: us-east-2
Services: auth, pdf, users
Max Wait: 300 seconds

This will update target groups for all specified services. Continue? (yes/no): yes


========================================
Phase 1: Verify Tasks are RUNNING
========================================

Checking auth tasks...
  Cluster: authapi-cluster
  ✅ Task is RUNNING
     Task ID: a1b2c3d4e5f67890
     Private IP: 10.0.1.123

Checking pdf tasks...
  Cluster: pdfcreator-cluster
  ⏳ No running tasks yet. Waiting...
  ⏳ No running tasks yet. Waiting...
  ⏳ No running tasks yet. Waiting...
  [... continues ...]
  ❌ Task did not reach RUNNING state within 300 seconds

Checking users tasks...
  Cluster: user-management-cluster
  ⏳ No running tasks yet. Waiting...
  ⏳ Task status: PROVISIONING. Waiting...
  ⏳ Task status: PENDING. Waiting...
  ⏳ Task status: RUNNING. Waiting...
  ❌ Task STOPPED: Essential container exited


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

Waiting up to 120 seconds for targets to become healthy...

  ✅ auth is healthy

🎉 All targets are healthy!


========================================
Summary
========================================

Service Status      Message                              TaskIP
------- ------      -------                              ------
AUTH    REGISTERED  Target registered successfully       10.0.1.123
PDF     TIMEOUT     Task not running within timeout      N/A
USERS   STOPPED     Essential container exited           N/A


⚠️  Partially successful: 1 / 3 services registered
❌ Failed: 2 services

Check current status with:
  .\check-status.ps1

```

---

## Skip Health Check Mode

```powershell
PS G:\Dev\start-engines-lambda> .\verify-and-update-target-groups.ps1 -SkipHealthCheck -Force

========================================
Verify ECS Tasks & Update Target Groups
========================================
Environment: dev
Region: us-east-2
Services: auth, pdf, fa, users, batch
Max Wait: 300 seconds


========================================
Phase 1: Verify Tasks are RUNNING
========================================

Checking auth tasks...
  Cluster: authapi-cluster
  ✅ Task is RUNNING
     Task ID: a1b2c3d4e5f67890
     Private IP: 10.0.1.123

[... checking other services ...]


========================================
Phase 2: Register Tasks with Target Groups
========================================

Registering auth with target group...
  IP: 10.0.1.123:8080
  Target Group: unified-auth-tg
  ✅ Successfully registered with target group

[... registering other services ...]


========================================
Summary
========================================

Service Status      Message                          TaskIP
------- ------      -------                          ------
AUTH    REGISTERED  Target registered successfully   10.0.1.123
PDF     REGISTERED  Target registered successfully   10.0.1.124
FA      REGISTERED  Target registered successfully   10.0.1.125
USERS   REGISTERED  Target registered successfully   10.0.1.126
BATCH   REGISTERED  Target registered successfully   10.0.1.127


✅ All services verified and registered: 5 / 5

Check current status with:
  .\check-status.ps1

```

**Note:** Phase 3 is skipped when using `-SkipHealthCheck`

---

## Common Error Messages

### No Running Tasks

```
Checking auth tasks...
  Cluster: authapi-cluster
  ⏳ No running tasks yet. Waiting...
  ⏳ No running tasks yet. Waiting...
  [... continues for 5 minutes ...]
  ❌ Task did not reach RUNNING state within 300 seconds
```

**Cause:** No tasks are running in the cluster  
**Solution:** Run `.\start-all-services.ps1` first, or check if tasks failed to start

### Task Stopped

```
Checking pdf tasks...
  Cluster: pdfcreator-cluster
  ⏳ Task status: PROVISIONING. Waiting...
  ⏳ Task status: PENDING. Waiting...
  ❌ Task STOPPED: Essential container in task exited
```

**Cause:** Task crashed or failed health checks  
**Solution:** Check CloudWatch logs for the task, fix the issue, restart the task

### Registration Failed

```
Registering fa with target group...
  IP: 10.0.1.125:2531
  Target Group: unified-fa-tg
  ❌ Failed to register: TargetGroupNotFound
```

**Cause:** Target group ARN is incorrect or doesn't exist  
**Solution:** Verify target group ARN in the script configuration

### Target Stays Unhealthy

```
========================================
Phase 3: Verify Target Health
========================================

Waiting up to 120 seconds for targets to become healthy...

  ⏳ auth is initial
  ⏳ auth is initial
  [... continues ...]
  ⏳ auth is initial
  ❌ auth is unhealthy: Target.FailedHealthChecks
```

**Cause:** Application isn't responding to health checks correctly  
**Solution:**
1. Check target group health check configuration
2. Verify application is listening on correct port
3. Check security groups allow ALB to reach task
4. Review application logs

---

## Timing Information

| Phase | Typical Duration |
|-------|-----------------|
| Phase 1: Verify Tasks RUNNING | 30-90 seconds (if starting from PROVISIONING) |
| Phase 1: Verify Tasks RUNNING | 0-5 seconds (if already RUNNING) |
| Phase 2: Register with TG | 1-2 seconds per service |
| Phase 3: Wait for Healthy | 30-120 seconds |
| **Total (from PROVISIONING)** | **2-4 minutes** |
| **Total (already RUNNING)** | **30-90 seconds** |

---

## Comparing to check-status.ps1

After running `verify-and-update-target-groups.ps1`, you can use `check-status.ps1` to see the final state:

```powershell
PS G:\Dev\start-engines-lambda> .\check-status.ps1

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

Service Cluster                 RunningTasks HealthyTargets UnhealthyTargets Port Status
------- -------                 ------------ -------------- ---------------- ---- ------
AUTH    authapi-cluster         1            1              0                8080 Running & Healthy
BATCH   batch-engine            1            1              0                8080 Running & Healthy
FA      fa-engine-cluster       1            1              0                2531 Running & Healthy
PDF     pdfcreator-cluster      1            1              0                9080 Running & Healthy
USERS   user-management-cluster 1            1              0                8080 Running & Healthy

Total Services Running: 5
Total Services Stopped: 0
Total Healthy Targets: 5
```

