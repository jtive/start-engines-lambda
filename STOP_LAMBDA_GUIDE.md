# Stop Engines Lambda Guide

## Overview

The `stop-engines-lambda` function stops all running ECS tasks across your configured clusters and optionally deregisters them from target groups. Perfect for:
- **Cost savings** during off-hours
- **Development environments** (stop at night, start in morning)
- **Emergency shutdown** of all services
- **Maintenance windows**

---

## Features

✅ **Stop all or specific services**  
✅ **Deregister from target groups** (optional)  
✅ **Batch processing** across multiple clusters  
✅ **Detailed reporting** of stopped tasks  
✅ **Schedule support** (stop nightly/weekly)  

---

## Deployment

### Quick Deploy
```bash
chmod +x deploy-stop-lambda.sh
./deploy-stop-lambda.sh dev
```

### Manual Deploy
```bash
# Build
sam build --template template-stop.yaml

# Deploy
sam deploy \
    --template-file .aws-sam/build/template.yaml \
    --stack-name stop-engines-lambda-dev \
    --region us-east-2 \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        Environment=dev \
        TaskSubnets="subnet-xxx,subnet-yyy" \
        TaskSecurityGroups="sg-xxx" \
        UsersTargetGroupArn="arn:aws:..." \
        BatchTargetGroupArn="arn:aws:..."
```

---

## Usage

### 1. Stop All Services

```bash
# Using script
./stop-all-tasks.sh dev

# Or manually
aws lambda invoke \
    --function-name stop-engines-lambda-dev \
    --payload '{
        "source": "custom.app",
        "detail-type": "Stop ECS Tasks",
        "detail": {
            "services": [],
            "deregister_targets": true
        }
    }' \
    --region us-east-2 \
    response.json
```

### 2. Stop Specific Services

```bash
aws events put-events --entries '[{
    "Source": "custom.app",
    "DetailType": "Stop ECS Tasks",
    "Detail": "{\"services\":[\"auth\",\"pdf\"],\"deregister_targets\":true}"
}]'
```

### 3. Stop Without Deregistering

```bash
aws events put-events --entries '[{
    "Source": "custom.app",
    "DetailType": "Stop ECS Tasks",
    "Detail": "{\"services\":[],\"deregister_targets\":false}"
}]'
```

---

## Event Format

```json
{
  "source": "custom.app",
  "detail-type": "Stop ECS Tasks",
  "detail": {
    "services": ["auth", "pdf", "fa", "users", "batch"],  // Optional: empty for all
    "deregister_targets": true  // Optional: default true
  }
}
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `services` | array | `[]` (all) | List of services to stop |
| `deregister_targets` | boolean | `true` | Deregister from target groups |

### Supported Services
- `auth` - AuthAPI
- `pdf` - PDFCreator
- `fa` - FaEngine
- `users` - UserManagement
- `batch` - BatchEngineCall

---

## Scheduled Stops

### Enable Nightly Shutdown

Edit `template-stop.yaml` and uncomment the schedule:

```yaml
Events:
  ScheduledStop:
    Type: Schedule
    Properties:
      Schedule: cron(0 20 * * ? *)  # 8 PM UTC daily
      Description: Stop all ECS tasks nightly
      Enabled: true  # ← Change to true
```

### Common Schedules

| Schedule | Cron Expression | Description |
|----------|-----------------|-------------|
| Every night at 8 PM UTC | `cron(0 20 * * ? *)` | Weekday nights |
| Weekends only | `cron(0 20 ? * FRI *)` | Friday 8 PM |
| Every weekday at 6 PM | `cron(0 18 ? * MON-FRI *)` | Business hours |

After editing, redeploy:
```bash
./deploy-stop-lambda.sh dev
```

---

## Response Format

```json
{
  "statusCode": 200,
  "body": {
    "message": "Successfully stopped 5 tasks across 3 services",
    "total_tasks_stopped": 5,
    "services_processed": 3,
    "results": [
      {
        "service": "auth",
        "cluster": "auth-cluster",
        "tasks_stopped": 2,
        "targets_deregistered": 2,
        "task_ids": ["abc123", "def456"],
        "status": "success"
      },
      {
        "service": "pdf",
        "cluster": "pdf-cluster",
        "tasks_stopped": 0,
        "status": "no_tasks"
      }
    ]
  }
}
```

---

## Monitoring

### CloudWatch Logs
```bash
# Tail logs
aws logs tail /aws/lambda/stop-engines-lambda-dev --follow --region us-east-2

# Get recent errors
aws logs filter-log-events \
    --log-group-name /aws/lambda/stop-engines-lambda-dev \
    --filter-pattern "ERROR"
```

### Check ECS Tasks
```bash
# List running tasks (should be empty after stop)
aws ecs list-tasks --cluster auth-cluster --desired-status RUNNING

# Check all clusters
for cluster in auth-cluster pdf-cluster fa-cluster users-cluster batch-cluster; do
    echo "Cluster: $cluster"
    aws ecs list-tasks --cluster $cluster --desired-status RUNNING
done
```

### Check Target Groups
```bash
# Should show no healthy targets
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/unified-auth-tg/cecaa72dcd652062
```

---

## Cost Savings

### Typical Savings (Development Environment)

| Scenario | Running Hours | Monthly Cost | With Stop Lambda | Savings |
|----------|---------------|--------------|------------------|---------|
| 24/7 | 720 hrs | $150 | $150 | $0 |
| Business hours only (8-6, M-F) | ~200 hrs | $150 | $42 | **$108** |
| Business days only (9-5, M-F) | ~160 hrs | $150 | $33 | **$117** |
| Stop on weekends | ~480 hrs | $150 | $100 | **$50** |

**Assumptions**: 5 services @ $0.05/hour/service

### Best Practices for Cost Savings

1. **Development**: Stop nightly, start morning
   ```
   Stop:  8 PM UTC (cron: 0 20 * * ? *)
   Start: 8 AM UTC (cron: 0 8 * * ? *)
   ```

2. **Staging**: Stop weekends
   ```
   Stop:  Friday 6 PM (cron: 0 18 ? * FRI *)
   Start: Monday 8 AM (cron: 0 8 ? * MON *)
   ```

3. **Production**: Manual stops only (for maintenance)

---

## Pairing with Start Lambda

### Morning Auto-Start, Evening Auto-Stop

1. **Stop Lambda** (evening):
   ```yaml
   Schedule: cron(0 20 * * ? *)  # 8 PM UTC
   ```

2. **Start Lambda** (morning):
   Edit `template.yaml` and add:
   ```yaml
   ScheduledStart:
     Type: Schedule
     Properties:
       Schedule: cron(0 8 * * ? *)  # 8 AM UTC
       Input: '{"detail":{"service":""}}'  # Empty = start all
   ```

### Manual Control

Create convenient aliases:
```bash
# Stop all
alias stop-all='./stop-all-tasks.sh dev'

# Start all
alias start-all='./start-all-tasks.sh dev'

# Stop specific
alias stop-auth='aws events put-events --entries "[{\"Source\":\"custom.app\",\"DetailType\":\"Stop ECS Tasks\",\"Detail\":\"{\\\"services\\\":[\\\"auth\\\"]}\"}]"'
```

---

## Troubleshooting

### Issue: Lambda times out
**Cause**: Too many tasks to stop  
**Solution**: Increase timeout in `template-stop.yaml`:
```yaml
Timeout: 600  # 10 minutes
```

### Issue: Permissions error
**Cause**: Missing IAM permissions  
**Solution**: Check CloudWatch logs and add missing permissions to `StopLambdaExecutionRole`

### Issue: Tasks not stopping
**Cause**: Tasks may be protected or cluster name incorrect  
**Solution**: 
```bash
# Check cluster names
aws ecs list-clusters

# Verify tasks exist
aws ecs list-tasks --cluster auth-cluster
```

### Issue: Deregistration fails
**Cause**: Target already deregistered or target group not found  
**Solution**: This is a warning, not an error. Tasks are still stopped.

---

## Example: Daily Dev Environment Workflow

### Setup (one time)
```bash
# Deploy both lambdas
./deploy.sh dev
./deploy-stop-lambda.sh dev

# Enable scheduled stop (8 PM) and start (8 AM)
# Edit templates and redeploy
```

### Daily Usage
```bash
# Morning (if not auto-started)
./start-all-tasks.sh dev

# Evening (if not auto-stopped)
./stop-all-tasks.sh dev
```

### Ad-hoc
```bash
# Stop just auth for debugging
aws events put-events --entries '[{
    "Source": "custom.app",
    "DetailType": "Stop ECS Tasks",
    "Detail": "{\"services\":[\"auth\"]}"
}]'

# Restart auth
aws events put-events --entries '[{
    "Source": "custom.app",
    "DetailType": "Start ECS Task",
    "Detail": "{\"service\":\"auth\"}"
}]'
```

---

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Stop Dev Environment

on:
  schedule:
    - cron: '0 20 * * *'  # 8 PM UTC daily
  workflow_dispatch:  # Manual trigger

jobs:
  stop-tasks:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-2
      
      - name: Stop all ECS tasks
        run: |
          aws lambda invoke \
            --function-name stop-engines-lambda-dev \
            --payload '{"source":"custom.app","detail-type":"Stop ECS Tasks","detail":{"services":[]}}' \
            response.json
          cat response.json
```

---

## Summary

✅ **Deployed**: Stop Lambda function  
✅ **Usage**: `./stop-all-tasks.sh` or EventBridge events  
✅ **Scheduling**: Optional cron schedules  
✅ **Cost Savings**: Up to $117/month in dev environments  
✅ **Paired**: Works with start-engines-lambda  

**💰 Cost Tip**: Stop tasks when not in use to save $$$ on Fargate/EC2 costs!

