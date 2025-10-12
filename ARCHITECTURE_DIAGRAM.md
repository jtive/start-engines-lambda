# Architecture Diagrams

## Current Architecture (What You Asked For)

```
┌─────────────────────────────────────────────────────────────────┐
│                    EventBridge (Default Event Bus)               │
│                                                                   │
│  Event: { "source": "custom.app",                                │
│           "detail-type": "Start ECS Task",                       │
│           "detail": { "service": "auth" } }                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Lambda: start-engines-lambda                  │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 1. Parse EventBridge event                               │   │
│  │ 2. Get service config from config.py                     │   │
│  │ 3. Start ECS task (ecs_handler.py)                       │   │
│  │ 4. Wait for RUNNING state                                │   │
│  │ 5. Extract private IP                                     │   │
│  │ 6. Register with target group (target_group_handler.py)  │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────┬──────────────────────────────────┬─────────────────────┘
         │                                   │
         ▼                                   ▼
┌────────────────────┐              ┌────────────────────┐
│   ECS Cluster      │              │  Target Group      │
│                    │              │                    │
│  ┌──────────────┐  │              │  ┌──────────────┐ │
│  │ Start Task   │  │              │  │ Register IP  │ │
│  │ Wait RUNNING │  │              │  │ + Port       │ │
│  │ Get IP       │  │              │  └──────────────┘ │
│  └──────────────┘  │              └─────────┬──────────┘
└────────────────────┘                        │
                                              ▼
                                    ┌────────────────────┐
                                    │ Application Load   │
                                    │ Balancer (ALB)     │
                                    └────────────────────┘
```

---

## Service Configuration Mapping

```
┌────────────────────────────────────────────────────────────────────┐
│                         config.py                                   │
│                                                                      │
│  SERVICE_MAPPINGS = {                                               │
│                                                                      │
│    'auth': {                                                        │
│      cluster: 'auth-cluster'                                        │
│      task_definition: 'auth-api-task'                               │
│      target_group: 'arn:...auth-lb/...'                            │
│      port: 8080                                                     │
│    },                                                               │
│                                                                      │
│    'pdf': {                                                         │
│      cluster: 'pdf-cluster'                                         │
│      task_definition: 'pdf-creator-task'                            │
│      target_group: 'arn:...pdf-lb/...'                             │
│      port: 9080                                                     │
│    },                                                               │
│                                                                      │
│    'fa': {                                                          │
│      cluster: 'fa-cluster'                                          │
│      task_definition: 'fa-engine-task'                              │
│      target_group: 'arn:...fa2-tg/...'                             │
│      port: 2531                                                     │
│    },                                                               │
│                                                                      │
│    'users': { ... },                                                │
│    'batch': { ... }                                                 │
│  }                                                                  │
└────────────────────────────────────────────────────────────────────┘
```

---

## Detailed Flow Diagram

```
┌────────────┐
│ Your App   │
│ (.NET/etc) │
└──────┬─────┘
       │
       │ AWS EventBridge PutEvents API
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│ EventBridge Event                                            │
│ {                                                            │
│   "source": "custom.app",                                    │
│   "detail-type": "Start ECS Task",                           │
│   "detail": { "service": "auth" }                            │
│ }                                                            │
└──────┬──────────────────────────────────────────────────────┘
       │
       │ EventBridge Rule matches pattern
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│ Lambda: lambda_handler()                                     │
│                                                              │
│ Step 1: Parse event                                          │
│   ├─ Get service name from event.detail.service             │
│   └─ Validate event structure                               │
│                                                              │
│ Step 2: Get configuration (config.py)                        │
│   ├─ Look up service in SERVICE_MAPPINGS                    │
│   ├─ Get cluster name, task def, target group ARN          │
│   ├─ Get subnets, security groups                           │
│   └─ Apply any overrides from event                         │
│                                                              │
│ Step 3: Start ECS Task (ecs_handler.py)                     │
│   ├─ Call ECS RunTask API                                   │
│   ├─ Parameters:                                             │
│   │   • cluster                                              │
│   │   • taskDefinition                                       │
│   │   • launchType: FARGATE                                  │
│   │   • networkConfiguration: subnets, SGs                   │
│   └─ Get task ARN                                            │
│                                                              │
│ Step 4: Wait for RUNNING (ecs_handler.py)                   │
│   ├─ Poll ECS DescribeTasks every 5 seconds                 │
│   ├─ Check lastStatus == 'RUNNING'                          │
│   ├─ Extract private IP from ENI                            │
│   └─ Timeout after 5 minutes                                │
│                                                              │
│ Step 5: Register Target (target_group_handler.py)           │
│   ├─ Call ELB RegisterTargets API                           │
│   ├─ Parameters:                                             │
│   │   • TargetGroupArn                                       │
│   │   • Targets: [{ Id: privateIP, Port: port }]           │
│   └─ Optionally wait for healthy status                     │
│                                                              │
│ Step 6: Return Success                                       │
│   └─ Return: {                                               │
│         statusCode: 200,                                     │
│         body: {                                              │
│           taskArn, taskId, privateIp, port,                 │
│           targetGroupArn, healthStatus                       │
│         }                                                    │
│       }                                                      │
└─────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────┐
│ Result                                                       │
│                                                              │
│ ✅ ECS Task running at 10.0.1.100:8080                      │
│ ✅ Registered with auth-lb target group                     │
│ ✅ Health checks starting                                    │
│ ✅ Ready to receive traffic from ALB                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Network Flow (awsvpc mode)

```
┌────────────────────────────────────────────────────────────────┐
│                         VPC (us-east-2)                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │ Public Subnet                                           │   │
│  │                                                          │   │
│  │  ┌──────────────────────────┐                          │   │
│  │  │ Application Load Balancer │                          │   │
│  │  │ (ALB)                     │                          │   │
│  │  │                           │                          │   │
│  │  │ Listener: HTTPS:443       │                          │   │
│  │  │ Rules:                    │                          │   │
│  │  │  /api/auth/* → auth-tg   │                          │   │
│  │  │  /api/pdf/*  → pdf-tg    │                          │   │
│  │  │  /api/fa/*   → fa-tg     │                          │   │
│  │  └──────────┬────────────────┘                          │   │
│  └─────────────┼─────────────────────────────────────────┘   │
│                │                                               │
│                │ HTTP to target IP:port                        │
│                │                                               │
│  ┌─────────────┼─────────────────────────────────────────┐   │
│  │ Private Subnet                                         │   │
│  │             │                                           │   │
│  │             ▼                                           │   │
│  │  ┌─────────────────────┐                               │   │
│  │  │ ECS Task (Fargate)  │                               │   │
│  │  │                     │                               │   │
│  │  │ ENI: 10.0.1.100     │◄───── Lambda registers this  │   │
│  │  │ Port: 8080          │       IP with target group    │   │
│  │  │                     │                               │   │
│  │  │ ┌─────────────────┐ │                               │   │
│  │  │ │ AuthAPI         │ │                               │   │
│  │  │ │ Container       │ │                               │   │
│  │  │ │ Listening:8080  │ │                               │   │
│  │  │ └─────────────────┘ │                               │   │
│  │  └─────────────────────┘                               │   │
│  └────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

---

## Cost Optimization Architecture (Recommended)

### Before (Current - 5 ALBs)

```
┌──────────────┐
│ React App    │
└──────┬───────┘
       │
       ├──────────────┐
       │              │
       ▼              ▼
┌──────────┐    ┌──────────┐    ... 3 more ALBs
│ ALB 1    │    │ ALB 2    │
│ $16/mo   │    │ $16/mo   │    Total: ~$200/month
└────┬─────┘    └────┬─────┘
     │               │
     ▼               ▼
   Auth           PDF
   ECS            ECS
```

### After (Optimized - 1 ALB)

```
┌──────────────┐
│ React App    │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────┐
│ Single ALB ($20/month)           │
│                                   │
│ Path-based routing:               │
│  /api/auth/*  → auth-tg          │
│  /api/pdf/*   → pdf-tg           │
│  /api/fa/*    → fa-tg            │
│  /api/users/* → users-tg         │
│  /api/batch/* → batch-tg         │
└──┬───┬───┬───┬───┬───────────────┘
   │   │   │   │   │
   ▼   ▼   ▼   ▼   ▼
  Auth PDF FA Users Batch
  ECS  ECS ECS ECS   ECS

💰 SAVINGS: $180/month = $2,160/year
```

---

## IAM Permissions Flow

```
┌────────────────────────────────────────────────────────────┐
│ Lambda Execution Role                                       │
│                                                             │
│ Permissions:                                                │
│                                                             │
│  ┌──────────────────────────────────────────────────┐     │
│  │ ECS Permissions                                   │     │
│  │ • ecs:RunTask                                     │     │
│  │ • ecs:DescribeTasks                               │     │
│  │ • ecs:DescribeTaskDefinition                      │     │
│  │ • ecs:StopTask                                    │     │
│  └──────────────────────────────────────────────────┘     │
│                                                             │
│  ┌──────────────────────────────────────────────────┐     │
│  │ ELB Permissions                                   │     │
│  │ • elasticloadbalancing:RegisterTargets            │     │
│  │ • elasticloadbalancing:DeregisterTargets          │     │
│  │ • elasticloadbalancing:DescribeTargetHealth       │     │
│  └──────────────────────────────────────────────────┘     │
│                                                             │
│  ┌──────────────────────────────────────────────────┐     │
│  │ EC2 Permissions                                   │     │
│  │ • ec2:DescribeNetworkInterfaces                   │     │
│  │ • ec2:DescribeSubnets                              │     │
│  │ • ec2:DescribeSecurityGroups                       │     │
│  └──────────────────────────────────────────────────┘     │
│                                                             │
│  ┌──────────────────────────────────────────────────┐     │
│  │ IAM Permissions                                   │     │
│  │ • iam:PassRole (for ECS task execution role)     │     │
│  └──────────────────────────────────────────────────┘     │
│                                                             │
│  ┌──────────────────────────────────────────────────┐     │
│  │ CloudWatch Logs                                   │     │
│  │ • logs:CreateLogGroup                             │     │
│  │ • logs:CreateLogStream                            │     │
│  │ • logs:PutLogEvents                               │     │
│  └──────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────┘
```

---

## File Structure and Dependencies

```
start-engines-lambda/
│
├── lambda_function.py ──────────┐
│   (Main handler)                │
│                                 │  imports
│   ┌─────────────────────────┐  │
│   │ lambda_handler()        │◄─┤
│   │  ├─ Parse event         │  │
│   │  ├─ Get config          │──┼─► config.py
│   │  ├─ Start ECS task      │──┼─► ecs_handler.py
│   │  └─ Register target     │──┼─► target_group_handler.py
│   └─────────────────────────┘  │
│                                 │
├── config.py                     │
│   ┌─────────────────────────┐  │
│   │ SERVICE_MAPPINGS        │◄─┤
│   │ get_service_config()    │  │
│   └─────────────────────────┘  │
│                                 │
├── ecs_handler.py                │
│   ┌─────────────────────────┐  │
│   │ ECSHandler class        │◄─┤
│   │  ├─ start_task()        │  │
│   │  ├─ _wait_for_running() │  │
│   │  └─ _extract_ip()       │  │
│   └─────────────────────────┘  │
│                                 │
├── target_group_handler.py       │
│   ┌─────────────────────────┐  │
│   │ TargetGroupHandler      │◄─┘
│   │  ├─ register_target()   │
│   │  ├─ get_target_health() │
│   │  └─ _wait_for_healthy() │
│   └─────────────────────────┘
│
├── requirements.txt
│   • boto3>=1.28.0
│   • pytest (for testing)
│
├── template.yaml
│   (SAM deployment template)
│
└── tests/
    ├── test_lambda_function.py
    └── test_config.py
```

---

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Developer Workstation                                        │
│                                                              │
│  1. sam build ──────► Package code + dependencies           │
│                                                              │
│  2. sam deploy ─────► Upload to S3                          │
│         │                                                    │
│         └───────────► Create CloudFormation Stack           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ AWS CloudFormation                                           │
│                                                              │
│  Creates:                                                    │
│   ├─ Lambda Function (start-engines-lambda-dev)            │
│   ├─ IAM Execution Role (with policies)                     │
│   ├─ CloudWatch Log Group                                   │
│   └─ EventBridge Rule (triggers Lambda)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ Deployed Resources (AWS Region: us-east-2)                  │
│                                                              │
│  Lambda Function: start-engines-lambda-dev                  │
│  EventBridge Rule: Start ECS Task event pattern            │
│  IAM Role: start-engines-lambda-role-dev                    │
│  Log Group: /aws/lambda/start-engines-lambda-dev            │
└─────────────────────────────────────────────────────────────┘
```

---

## Integration Patterns

### Pattern 1: Direct EventBridge (Recommended)

```
Your .NET App → EventBridge PutEvents → Lambda → ECS
```

### Pattern 2: API Gateway

```
Your .NET App → API Gateway → Lambda → ECS
```

### Pattern 3: Step Functions (For Complex Workflows)

```
Trigger → Step Functions → Lambda → ECS
                         ↓
                    (orchestration)
```

### Pattern 4: Scheduled (Cron)

```
CloudWatch Events (cron) → Lambda → ECS
(e.g., start tasks every morning)
```

