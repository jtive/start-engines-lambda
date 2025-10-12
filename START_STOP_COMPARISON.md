# Start vs Stop Lambda Comparison

## Overview

You now have **TWO complementary Lambda functions** for complete ECS task lifecycle management:

| Lambda | Purpose | When to Use |
|--------|---------|-------------|
| **start-engines-lambda** | Starts ECS tasks and registers with target groups | - Morning startup<br>- On-demand scaling<br>- Event-driven deployment |
| **stop-engines-lambda** | Stops all ECS tasks and deregisters from target groups | - Evening shutdown<br>- Cost savings<br>- Maintenance windows |

---

## Quick Reference

### Start Lambda

**Function**: `start-engines-lambda-dev`

**Trigger Event**:
```json
{
  "source": "custom.app",
  "detail-type": "Start ECS Task",
  "detail": {
    "service": "auth"
  }
}
```

**What it does**:
1. ✅ Starts 1 ECS task in specified cluster
2. ✅ Waits for task to reach RUNNING state
3. ✅ Extracts task's private IP
4. ✅ Registers IP with target group
5. ✅ Returns task details

**Use cases**:
- Start individual services on demand
- Event-driven task deployment
- Auto-scaling based on events
- Scheduled morning startup

---

### Stop Lambda

**Function**: `stop-engines-lambda-dev`

**Trigger Event**:
```json
{
  "source": "custom.app",
  "detail-type": "Stop ECS Tasks",
  "detail": {
    "services": [],  // Empty = all services
    "deregister_targets": true
  }
}
```

**What it does**:
1. ✅ Lists all running tasks in clusters
2. ✅ Stops all tasks (or specific services)
3. ✅ Deregisters IPs from target groups
4. ✅ Returns count of stopped tasks

**Use cases**:
- Stop all services at end of day
- Cost savings during off-hours
- Emergency shutdown
- Maintenance windows

---

## Deployment

### Deploy Both Lambdas

```bash
# Start Lambda
cd D:\Dev\start-engines-lambda
sam build
sam deploy

# Stop Lambda
sam build --template template-stop.yaml
sam deploy \
    --template-file .aws-sam/build/template.yaml \
    --stack-name stop-engines-lambda-dev \
    --region us-east-2 \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        Environment=dev \
        TaskSubnets="subnet-00347cba6de355f15,subnet-0c28cf78daa71a342,subnet-0e4374ad2092dee14" \
        TaskSecurityGroups="sg-0375466cf9847b96d" \
        UsersTargetGroupArn="arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/users-tg/f9a22b2edc13281f" \
        BatchTargetGroupArn="arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/batch-tg/4016a351002f823f"
```

---

## Common Workflows

### 1. Daily Dev Environment (Manual)

**Morning**:
```bash
# Start all services
aws events put-events --entries '[
  {"Source":"custom.app","DetailType":"Start ECS Task","Detail":"{\"service\":\"auth\"}"},
  {"Source":"custom.app","DetailType":"Start ECS Task","Detail":"{\"service\":\"pdf\"}"},
  {"Source":"custom.app","DetailType":"Start ECS Task","Detail":"{\"service\":\"fa\"}"}
]'
```

**Evening**:
```bash
# Stop all services
aws lambda invoke --function-name stop-engines-lambda-dev --payload '{"source":"custom.app","detail-type":"Stop ECS Tasks","detail":{"services":[]}}' response.json
```

---

### 2. Scheduled Auto Start/Stop

**Enable in CloudFormation templates**:

**Start Lambda** (`template.yaml`):
```yaml
ScheduledStart:
  Type: Schedule
  Properties:
    Schedule: cron(0 8 * * ? *)  # 8 AM UTC
    Input: '{"detail":{"service":"auth"}}'  # Start auth
```

**Stop Lambda** (`template-stop.yaml`):
```yaml
ScheduledStop:
  Type: Schedule
  Properties:
    Schedule: cron(0 20 * * ? *)  # 8 PM UTC
    Enabled: true
```

---

### 3. Event-Driven Scaling

**Scale Up** (on high traffic):
```bash
# CloudWatch alarm triggers EventBridge event
aws events put-events --entries '[{
    "Source": "cloudwatch.alarm",
    "DetailType": "Start ECS Task",
    "Detail": "{\"service\":\"auth\"}"
}]'
```

**Scale Down** (on low traffic):
```bash
# CloudWatch alarm triggers stop
aws events put-events --entries '[{
    "Source": "cloudwatch.alarm",
    "DetailType": "Stop ECS Tasks",
    "Detail": "{\"services\":[\"auth\"]}"
}]'
```

---

### 4. Emergency Procedures

**Emergency Shutdown**:
```bash
# Stop everything immediately
./stop-all-tasks.sh dev
```

**Quick Restart**:
```bash
# Stop all
./stop-all-tasks.sh dev

# Wait 30 seconds
sleep 30

# Start all
for service in auth pdf fa users batch; do
    aws events put-events --entries "[{ "Source\":\"custom.app\", "DetailType\":\"Start ECS Task\", "Detail\":\"{\\\"service\\\":\\\"$service\\\"}\" }]"
done
```

---

## Cost Savings Scenarios

### Scenario 1: Business Hours Only (8 AM - 6 PM, Mon-Fri)

**Setup**:
- Stop: Monday-Friday at 6 PM (`cron(0 18 ? * MON-FRI *)`)
- Start: Monday-Friday at 8 AM (`cron(0 8 ? * MON-FRI *)`)

**Running time**: ~200 hours/month (vs 720 hours/month)

**Savings**: ~72% reduction in Fargate/EC2 costs

| Service | Full-time Cost | Business Hours | Savings |
|---------|----------------|----------------|---------|
| 5 Fargate tasks (0.25 vCPU, 0.5 GB) | $150/month | $42/month | **$108/month** |

---

### Scenario 2: Weekday Only (Stop Fri 6 PM, Start Mon 8 AM)

**Setup**:
- Stop: Friday at 6 PM (`cron(0 18 ? * FRI *)`)
- Start: Monday at 8 AM (`cron(0 8 ? * MON *)`)

**Running time**: ~480 hours/month (66% of time)

**Savings**: ~34% reduction

| Service | Full-time Cost | Weekday Only | Savings |
|---------|----------------|--------------|---------|
| 5 Fargate tasks | $150/month | $99/month | **$51/month** |

---

### Scenario 3: On-Demand (Start/Stop Manually)

**Setup**: No schedule, manual control only

**Typical usage**: 40 hours/week = ~160 hours/month

**Savings**: ~78% reduction

| Service | Full-time Cost | On-Demand | Savings |
|---------|----------------|-----------|---------|
| 5 Fargate tasks | $150/month | $33/month | **$117/month** |

---

## Monitoring Both Lambdas

### Check Lambda Status
```bash
# List both lambdas
aws lambda list-functions --query "Functions[?contains(FunctionName,'engines')].FunctionName"

# Get start lambda info
aws lambda get-function --function-name start-engines-lambda-dev

# Get stop lambda info
aws lambda get-function --function-name stop-engines-lambda-dev
```

### View Logs
```bash
# Start lambda logs
aws logs tail /aws/lambda/start-engines-lambda-dev --follow

# Stop lambda logs
aws logs tail /aws/lambda/stop-engines-lambda-dev --follow
```

### Check Recent Executions
```bash
# Start lambda invocations (last 24 hours)
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=start-engines-lambda-dev \
    --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 3600 \
    --statistics Sum

# Stop lambda invocations
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=stop-engines-lambda-dev \
    --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 3600 \
    --statistics Sum
```

---

## IAM Permissions Comparison

### Start Lambda Needs:
- ✅ `ecs:RunTask` - Start tasks
- ✅ `ecs:DescribeTasks` - Check task status
- ✅ `elasticloadbalancing:RegisterTargets` - Add to target group
- ✅ `iam:PassRole` - Pass execution role to task

### Stop Lambda Needs:
- ✅ `ecs:ListTasks` - Find running tasks
- ✅ `ecs:DescribeTasks` - Get task details
- ✅ `ecs:StopTask` - Stop tasks
- ✅ `elasticloadbalancing:DeregisterTargets` - Remove from target group

**Both share**:
- ✅ `ec2:DescribeNetworkInterfaces` - Get task IPs
- ✅ `logs:*` - CloudWatch Logs

---

## Best Practices

### 1. Use Descriptive Event Sources
```json
{
  "source": "ci-cd.deployment",  // vs "custom.app"
  "detail-type": "Start ECS Task"
}
```

### 2. Add Tags to Tasks
Modify `ecs_handler.py`:
```python
response = self.ecs_client.run_task(
    cluster=cluster,
    taskDefinition=task_definition,
    tags=[
        {'key': 'StartedBy', 'value': 'start-engines-lambda'},
        {'key': 'Environment', 'value': 'dev'}
    ]
)
```

### 3. Set Up Alarms
```bash
# Alert on start failures
aws cloudwatch put-metric-alarm \
    --alarm-name start-lambda-errors \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --dimensions Name=FunctionName,Value=start-engines-lambda-dev \
    --statistic Sum \
    --period 300 \
    --evaluation-periods 1 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold

# Alert on stop failures
aws cloudwatch put-metric-alarm \
    --alarm-name stop-lambda-errors \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --dimensions Name=FunctionName,Value=stop-engines-lambda-dev \
    --statistic Sum \
    --period 300 \
    --evaluation-periods 1 \
    --threshold 1 \
    --comparison-operator GreaterThanThreshold
```

### 4. Use Dead Letter Queues
Add to both templates:
```yaml
Properties:
  DeadLetterConfig:
    TargetArn: !GetAtt LambdaDLQ.Arn

Resources:
  LambdaDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: !Sub ${AWS::StackName}-dlq
```

---

## Troubleshooting

### Start Lambda Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "TaskDefinition not found" | ECS task def missing | Create task definition |
| "Insufficient resources" | No capacity in cluster | Wait or add capacity |
| "Target registration failed" | Wrong port/IP | Check task definition ports |

### Stop Lambda Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "No tasks found" | Tasks already stopped | This is normal |
| "Permission denied" | Missing IAM permissions | Add `ecs:StopTask` |
| "Deregistration failed" | Target already gone | This is a warning, not error |

---

## Summary

| Feature | Start Lambda | Stop Lambda |
|---------|--------------|-------------|
| **Purpose** | Start tasks | Stop tasks |
| **Operates on** | Individual services | All or specific services |
| **Target Groups** | Registers | Deregisters |
| **Use Case** | Scale up / Deploy | Scale down / Save costs |
| **Scheduling** | Per-service | Batch all services |
| **Cost Impact** | Increases costs | **Decreases costs** 💰 |

**Together**: Complete task lifecycle management with significant cost savings potential!

---

## Quick Commands Reference

```bash
# START LAMBDA
# Start specific service
aws events put-events --entries '[{"Source":"custom.app","DetailType":"Start ECS Task","Detail":"{\"service\":\"auth\"}"}]'

# STOP LAMBDA
# Stop all services
./stop-all-tasks.sh dev

# Stop specific services
aws lambda invoke \
    --function-name stop-engines-lambda-dev \
    --payload '{"source":"custom.app","detail-type":"Stop ECS Tasks","detail":{"services":["auth","pdf"]}}' \
    response.json

# MONITORING
# View start lambda logs
aws logs tail /aws/lambda/start-engines-lambda-dev --follow

# View stop lambda logs
aws logs tail /aws/lambda/stop-engines-lambda-dev --follow

# Check running tasks
aws ecs list-tasks --cluster auth-cluster --desired-status RUNNING
```

---

🎉 **You now have complete control over your ECS task lifecycle with automated cost savings!**

