# Target Group Verification Guide

## Problem: Race Condition with Target Group Registration

### The Issue

When using `start-all-services.ps1`, the Lambda function immediately registers ECS tasks with target groups as soon as they start. However, there's a race condition:

1. **Lambda invokes ECS `run_task`** - Task is created in PROVISIONING state
2. **Lambda waits for task to be RUNNING** - Usually takes 30-90 seconds
3. **Lambda registers task IP with target group** - Happens immediately when RUNNING
4. **Health checks begin** - ALB starts checking if target is healthy

The problem occurs in **Step 2-3**: While the Lambda function does wait for the task to reach RUNNING state, there can still be issues:

- Multiple concurrent starts can cause timing issues
- Network interface assignment delays
- Container startup time after task reaches RUNNING
- The PowerShell script doesn't verify success before moving to the next service

### The Solution

The new `verify-and-update-target-groups.ps1` script provides a **safe, verified approach**:

1. ✅ **Verify tasks are RUNNING** - Actively polls ECS until tasks are confirmed RUNNING
2. ✅ **Extract Private IPs** - Gets the actual private IP addresses from running tasks
3. ✅ **Register with Target Groups** - Only updates target groups once tasks are verified
4. ✅ **Health Check Verification** - Optionally waits for targets to become healthy
5. ✅ **Idempotent** - Safe to run multiple times; skips already healthy targets

## Usage

### Basic Usage

```powershell
# Verify and update all services
.\verify-and-update-target-groups.ps1
```

### With Options

```powershell
# Specific services only
.\verify-and-update-target-groups.ps1 -Services auth,pdf,users

# Different environment
.\verify-and-update-target-groups.ps1 -Environment prod -Region us-west-2

# Skip health check waiting (faster, but doesn't verify)
.\verify-and-update-target-groups.ps1 -SkipHealthCheck

# Skip confirmation prompt
.\verify-and-update-target-groups.ps1 -Force

# Custom timeouts
.\verify-and-update-target-groups.ps1 -MaxWaitSeconds 600 -HealthCheckWaitSeconds 180
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Environment` | `"dev"` | Environment name (dev, staging, prod) |
| `-Region` | `"us-east-2"` | AWS region |
| `-Services` | `@("auth", "pdf", "fa", "users", "batch")` | Services to verify and register |
| `-MaxWaitSeconds` | `300` (5 min) | Max time to wait for tasks to reach RUNNING |
| `-HealthCheckWaitSeconds` | `120` (2 min) | Max time to wait for health checks |
| `-SkipHealthCheck` | `false` | Skip waiting for targets to become healthy |
| `-Force` | `false` | Skip confirmation prompt |

## Recommended Workflows

### Option 1: Separate Start and Verify (Recommended)

**Best for: Production, when you want maximum control and verification**

```powershell
# Step 1: Start all services (Lambda handles initial registration)
.\start-all-services.ps1 -Force

# Step 2: Wait for tasks to stabilize
Start-Sleep -Seconds 60

# Step 3: Verify and update target groups (ensures everything is correct)
.\verify-and-update-target-groups.ps1 -Force

# Step 4: Check final status
.\check-status.ps1
```

### Option 2: Verify After Failed Starts

**Best for: When start-all-services.ps1 partially fails**

```powershell
# Start services (some may fail)
.\start-all-services.ps1

# Verify which ones are actually running and fix target groups
.\verify-and-update-target-groups.ps1
```

### Option 3: Quick Verification

**Best for: Development, when you just want to check current state**

```powershell
# Just verify current running tasks and update target groups
.\verify-and-update-target-groups.ps1 -SkipHealthCheck -Force
```

### Option 4: Individual Service Fix

**Best for: Fixing a single problematic service**

```powershell
# Start specific service
.\start-single-service.ps1 -Service pdf

# Verify just that service
.\verify-and-update-target-groups.ps1 -Services pdf -Force
```

## Script Phases

### Phase 1: Verify Tasks are RUNNING

```
Checking auth tasks...
  Cluster: authapi-cluster
  ⏳ No running tasks yet. Waiting...
  ⏳ Task status: PROVISIONING. Waiting...
  ⏳ Task status: PENDING. Waiting...
  ✅ Task is RUNNING
     Task ID: a1b2c3d4e5f6
     Private IP: 10.0.1.123
```

The script:
- Lists tasks in the cluster
- Describes task details to get status
- Waits for `lastStatus` to be `RUNNING`
- Extracts private IP from network interface attachments
- Handles STOPPED tasks gracefully with error messages

### Phase 2: Register Tasks with Target Groups

```
Registering auth with target group...
  IP: 10.0.1.123:8080
  Target Group: unified-auth-tg
  ℹ️  Target already registered. Current state: initial
  ✅ Successfully registered with target group
```

The script:
- Checks if target is already registered
- Skips registration if already healthy
- Registers target with correct IP and port
- Handles registration errors gracefully

### Phase 3: Verify Target Health (Optional)

```
Waiting up to 120 seconds for targets to become healthy...
  ⏳ auth is initial
  ⏳ pdf is initial
  ⏳ fa is initial
  
  Checking again in 10 seconds... (110 seconds remaining)
  
  ✅ auth is healthy
  ⏳ pdf is initial
  ⏳ fa is initial
  
  ...
  
🎉 All targets are healthy!
```

The script:
- Polls target health every 10 seconds
- Shows current state for each target
- Reports reasons for unhealthy targets
- Exits early if all become healthy

## Understanding Task States

### ECS Task States

| State | Description | Action |
|-------|-------------|--------|
| `PROVISIONING` | Task is being created | ⏳ Wait |
| `PENDING` | Task is pulling images, starting | ⏳ Wait |
| `ACTIVATING` | Task is activating | ⏳ Wait |
| `RUNNING` | Task is running | ✅ Extract IP and register |
| `DEACTIVATING` | Task is shutting down | ❌ Skip |
| `STOPPING` | Task is stopping | ❌ Skip |
| `DEPROVISIONING` | Task is being removed | ❌ Skip |
| `STOPPED` | Task has stopped | ❌ Report error |

### Target Health States

| State | Description | Typical Duration |
|-------|-------------|------------------|
| `initial` | Health checks haven't started | 5-10 seconds |
| `healthy` | Target is passing health checks | N/A (stable) |
| `unhealthy` | Target is failing health checks | Investigate issue |
| `unused` | Target is not in use | Check configuration |
| `draining` | Target is being deregistered | Wait or skip |
| `unavailable` | Target is not available | Check task status |

## Troubleshooting

### Tasks Won't Reach RUNNING State

**Symptoms:**
```
❌ Task did not reach RUNNING state within 300 seconds
```

**Common Causes:**
1. **Image pull errors** - Task can't pull Docker image
2. **Insufficient resources** - No capacity in cluster/subnets
3. **Security group issues** - Can't access required services
4. **Task definition errors** - Invalid configuration

**Check:**
```powershell
# View task details in AWS Console
aws ecs describe-tasks --cluster authapi-cluster --tasks <task-id>
```

### Targets Stay in "initial" State

**Symptoms:**
```
⏳ auth is initial
⏳ auth is initial
(continues forever)
```

**Common Causes:**
1. **Health check path wrong** - Target group checking wrong path
2. **Port mismatch** - Health check using wrong port
3. **Security group blocking** - ALB can't reach task
4. **Application not responding** - Container not healthy

**Check Target Group Settings:**
```powershell
aws elbv2 describe-target-groups --target-group-arns <arn>
aws elbv2 describe-target-health --target-group-arn <arn>
```

### Targets Become "unhealthy"

**Symptoms:**
```
❌ auth is unhealthy: Target.FailedHealthChecks
```

**Common Causes:**
1. **Application error** - Container is crashing or not responding
2. **Wrong health check configuration** - Expecting wrong response
3. **Timeout issues** - Health check timeout too short
4. **Network issues** - Intermittent connectivity

**Check Container Logs:**
```powershell
aws logs tail /ecs/<cluster>/<task-family> --follow
```

### "Target already registered" But Shows Unhealthy

**Symptoms:**
```
ℹ️  Target already registered. Current state: unhealthy
❌ Failed to register: Target already registered
```

**Solution:**
This is actually GOOD - the script detected existing registration and won't duplicate it. The unhealthy state needs to be investigated separately.

**Actions:**
1. Check container logs for errors
2. Verify health check configuration
3. Test the endpoint directly: `curl http://<task-ip>:<port>/health`
4. Review security groups

## Comparison with start-all-services.ps1

| Feature | start-all-services.ps1 | verify-and-update-target-groups.ps1 |
|---------|------------------------|-------------------------------------|
| **What it does** | Invokes Lambda to start tasks | Verifies running tasks & updates TGs |
| **When to use** | Initial startup | After startup, or when TGs need fixing |
| **Task verification** | ❌ No (relies on Lambda) | ✅ Yes (actively polls) |
| **Waits for RUNNING** | ⚠️ Lambda does, but not verified | ✅ Yes (with timeout) |
| **Target group update** | ⚠️ Lambda does immediately | ✅ Only after verification |
| **Health check verification** | ❌ No | ✅ Yes (optional) |
| **Idempotent** | ❌ No (creates new tasks) | ✅ Yes (safe to re-run) |
| **Error recovery** | ❌ Limited | ✅ Detailed error reporting |
| **Best for** | Fresh starts | Verification & recovery |

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Start ECS Services
  run: |
    pwsh -Command ".\start-all-services.ps1 -Force"

- name: Wait for Tasks to Stabilize
  run: sleep 60

- name: Verify and Update Target Groups
  run: |
    pwsh -Command ".\verify-and-update-target-groups.ps1 -Force"

- name: Verify All Services Healthy
  run: |
    pwsh -Command ".\check-status.ps1"
```

### Jenkins Example

```groovy
stage('Start Services') {
    steps {
        powershell './start-all-services.ps1 -Force'
    }
}

stage('Verify Target Groups') {
    steps {
        sleep 60
        powershell './verify-and-update-target-groups.ps1 -Force -HealthCheckWaitSeconds 180'
    }
}
```

## When to Use Which Script

### Use `start-all-services.ps1` when:
- ✅ Starting services for the first time
- ✅ All services are currently stopped
- ✅ You want Lambda to handle everything automatically
- ✅ You're okay with potential race conditions

### Use `verify-and-update-target-groups.ps1` when:
- ✅ Services are already running but target groups are wrong
- ✅ `start-all-services.ps1` completed but services aren't healthy
- ✅ You want to verify everything is correct before proceeding
- ✅ You need detailed status information
- ✅ Recovery from partial failures
- ✅ Production deployments requiring verification

### Use both in sequence when:
- ✅ Production deployments
- ✅ Maximum reliability required
- ✅ Automated CI/CD pipelines
- ✅ You want the best of both approaches

## Best Practices

1. **Always verify in production**
   ```powershell
   .\start-all-services.ps1 -Environment prod -Force
   Start-Sleep -Seconds 90
   .\verify-and-update-target-groups.ps1 -Environment prod -Force
   ```

2. **Monitor the process**
   - Watch the output for errors
   - Don't ignore yellow warnings
   - Check CloudWatch logs if issues occur

3. **Use appropriate timeouts**
   - Development: Shorter timeouts (default)
   - Production: Longer timeouts for safety
   ```powershell
   .\verify-and-update-target-groups.ps1 -MaxWaitSeconds 600 -HealthCheckWaitSeconds 300
   ```

4. **Keep configuration in sync**
   - Ensure PowerShell configs match `config.py`
   - Update target group ARNs when they change
   - Verify cluster names are correct

5. **Document your process**
   - Add this to your deployment runbook
   - Train team members on both scripts
   - Keep this guide updated

## Additional Resources

- AWS ECS Task Lifecycle: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-lifecycle.html
- ALB Target Health: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html
- Troubleshooting ECS: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/troubleshooting.html

## Support

If you encounter issues:

1. Check this guide first
2. Review CloudWatch logs
3. Use `check-status.ps1` for current state
4. Check AWS Console for detailed error messages
5. Review security group and network configuration

