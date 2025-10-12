# Setting Up ECS Resources

Your Lambda is deployed and working! Now you need to create the ECS infrastructure.

## Current Status

✅ Lambda deployed: `start-engines-lambda-dev`  
✅ Target groups created: All 5 target groups ready  
✅ VPC Configuration: `vpc-0e5394487855ee994`  
⚠️ Need: ECS clusters and task definitions

---

## Option 1: Quick Setup (Use Your Existing Services)

If you already have these services running, you just need to update the Lambda configuration with the correct cluster and task definition names.

### Check Existing Clusters:
```bash
aws ecs list-clusters --region us-east-2
```

### Check Existing Task Definitions:
```bash
aws ecs list-task-definitions --region us-east-2 --status ACTIVE
```

### Update Lambda Environment Variables:
```bash
aws lambda update-function-configuration \
  --region us-east-2 \
  --function-name start-engines-lambda-dev \
  --environment Variables="{
    AWS_ACCOUNT_ID=486151888818,
    SUBNETS=subnet-00347cba6de355f15,subnet-0c28cf78daa71a342,subnet-0e4374ad2092dee14,
    SECURITY_GROUPS=sg-0375466cf9847b96d,
    AUTH_CLUSTER=your-actual-auth-cluster-name,
    AUTH_TASK_DEF=your-actual-auth-task-def,
    PDF_CLUSTER=your-actual-pdf-cluster-name,
    PDF_TASK_DEF=your-actual-pdf-task-def,
    FA_CLUSTER=your-actual-fa-cluster-name,
    FA_TASK_DEF=your-actual-fa-task-def,
    USERS_CLUSTER=your-actual-users-cluster-name,
    USERS_TASK_DEF=your-actual-users-task-def,
    BATCH_CLUSTER=your-actual-batch-cluster-name,
    BATCH_TASK_DEF=your-actual-batch-task-def,
    USERS_TARGET_GROUP_ARN=arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/users-tg/f9a22b2edc13281f,
    BATCH_TARGET_GROUP_ARN=arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/batch-tg/4016a351002f823f,
    LAUNCH_TYPE=FARGATE,
    ASSIGN_PUBLIC_IP=ENABLED,
    TASK_WAIT_TIMEOUT=300,
    TASK_POLL_INTERVAL=5,
    LOG_LEVEL=INFO
  }"
```

---

## Option 2: Create New ECS Infrastructure

### 1. Create ECS Clusters

```bash
# Auth Cluster
aws ecs create-cluster --region us-east-2 --cluster-name auth-cluster

# PDF Cluster
aws ecs create-cluster --region us-east-2 --cluster-name pdf-cluster

# FA Cluster
aws ecs create-cluster --region us-east-2 --cluster-name fa-cluster

# Users Cluster
aws ecs create-cluster --region us-east-2 --cluster-name users-cluster

# Batch Cluster
aws ecs create-cluster --region us-east-2 --cluster-name batch-cluster
```

### 2. Create Task Definitions

You'll need to create task definitions for each service. Based on your Dockerfiles:

#### Auth API Task Definition (auth-api-task.json):
```json
{
  "family": "auth-api-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "taskRoleArn": "arn:aws:iam::486151888818:role/ecsTaskExecutionRole",
  "executionRoleArn": "arn:aws:iam::486151888818:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "authapi-container",
      "image": "486151888818.dkr.ecr.us-east-2.amazonaws.com/auth-api:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/auth-api",
          "awslogs-region": "us-east-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

**Register it:**
```bash
aws ecs register-task-definition --region us-east-2 --cli-input-json file://auth-api-task.json
```

#### PDF Creator Task Definition (pdf-creator-task.json):
```json
{
  "family": "pdf-creator-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "taskRoleArn": "arn:aws:iam::486151888818:role/ecsTaskExecutionRole",
  "executionRoleArn": "arn:aws:iam::486151888818:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "pdfcreator-container",
      "image": "486151888818.dkr.ecr.us-east-2.amazonaws.com/pdf-creator:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 9080,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/pdf-creator",
          "awslogs-region": "us-east-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

#### FA Engine Task Definition (fa-engine-task.json):
```json
{
  "family": "fa-engine-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "taskRoleArn": "arn:aws:iam::486151888818:role/ecsTaskExecutionRole",
  "executionRoleArn": "arn:aws:iam::486151888818:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "faengine-container",
      "image": "486151888818.dkr.ecr.us-east-2.amazonaws.com/fa-engine:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 2531,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "ASPNETCORE_URLS",
          "value": "http://+:2531"
        },
        {
          "name": "ASPNETCORE_HTTP_PORT",
          "value": "2531"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/fa-engine",
          "awslogs-region": "us-east-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### 3. Build and Push Docker Images

```bash
# Auth API
cd C:\Users\Jyten\source\repos\AuthAPI
docker build -t auth-api .
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 486151888818.dkr.ecr.us-east-2.amazonaws.com
docker tag auth-api:latest 486151888818.dkr.ecr.us-east-2.amazonaws.com/auth-api:latest
docker push 486151888818.dkr.ecr.us-east-2.amazonaws.com/auth-api:latest

# Repeat for PDF Creator, FA Engine, UserManagement, BatchEngineCall
```

---

## Option 3: Use Existing GitHub Actions

Since you mentioned your repos have GitHub Actions, you likely already have automated deployment pipelines. Check your `.github/workflows` directories for the deployment logic.

---

## Testing After Setup

Once you have the ECS resources created:

### Test Auth Service:
```bash
cd D:\Dev\start-engines-lambda
aws lambda invoke \
  --region us-east-2 \
  --function-name start-engines-lambda-dev \
  --payload fileb://test-event-auth.json \
  --cli-binary-format raw-in-base64-out \
  response.json

Get-Content response.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

### Monitor Logs:
```bash
aws logs tail /aws/lambda/start-engines-lambda-dev --follow --region us-east-2
```

### Check ECS Tasks:
```bash
aws ecs list-tasks --cluster auth-cluster --region us-east-2
```

### Check Target Health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/auth-lb/0f8e49d7cd37c0c9 \
  --region us-east-2
```

---

## What the Lambda Does (Recap)

When you send an EventBridge event:
```json
{
  "source": "custom.app",
  "detail-type": "Start ECS Task",
  "detail": { "service": "auth" }
}
```

The Lambda:
1. ✅ Looks up `auth` configuration
2. ✅ Starts task in `auth-cluster` using `auth-api-task` definition
3. ✅ Waits for task to reach RUNNING state
4. ✅ Extracts task's private IP address
5. ✅ Registers IP:8080 with `auth-lb` target group
6. ✅ Returns success with task details

---

## Need Help?

If you already have ECS infrastructure, run:
```bash
# List your clusters
aws ecs list-clusters --region us-east-2

# List your task definitions
aws ecs list-task-definitions --region us-east-2 --status ACTIVE
```

Then update the Lambda environment variables to match your actual resource names!

