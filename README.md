# ECS Task Management Lambdas

Two production-ready Python Lambda functions that provide complete ECS task lifecycle management:
- **Start Lambda**: Starts ECS tasks and registers them with Application Load Balancer target groups
- **Stop Lambda**: Stops all ECS tasks and deregisters them from target groups

## ✨ Features

### Start Lambda (`start-engines-lambda`)
- 🚀 **Automatic ECS Task Management**: Starts tasks and waits for RUNNING state
- 🎯 **Target Group Registration**: Automatically registers tasks with ALB target groups
- 🔧 **Multi-Service Support**: Pre-configured for 5 microservices
- ⚙️ **Flexible Configuration**: Event-level overrides supported

### Stop Lambda (`stop-engines-lambda`)
- 🛑 **Batch Task Stopping**: Stop all or specific services at once
- 🎯 **Target Group Deregistration**: Automatically deregisters targets
- 💰 **Cost Savings**: Save up to $117/month in dev environments
- ⏰ **Scheduling Support**: Optional auto-shutdown (nightly/weekly)

### Common Features
- 📊 **Comprehensive Logging**: CloudWatch integration with detailed execution logs
- 🧪 **Fully Tested**: Unit tests with mocked AWS services
- 💰 **Cost Optimized**: Combined ALB + task scheduling savings = **$292/month**

## 🏗️ Architecture

### Start Lambda Flow
```
EventBridge → Start Lambda → ECS (start task) → Wait for RUNNING → Get IP → Register with Target Group
```

### Stop Lambda Flow
```
EventBridge/Schedule → Stop Lambda → List Running Tasks → Stop Tasks → Deregister IPs from Target Groups
```

### Complete Lifecycle
1. ✅ **Start**: Receive event → Start task → Wait for RUNNING → Register with target group
2. ✅ **Stop**: Receive event → List tasks → Stop all tasks → Deregister from target groups
3. ✅ **Monitoring**: CloudWatch Logs + Target health checks
4. ✅ **Cost Optimization**: Unified ALB + scheduled stops = **$292/month savings**

## 📋 Prerequisites

- **AWS Account** with appropriate permissions
- **Python 3.12** (or 3.9+)
- **AWS CLI** configured
- **AWS SAM CLI** installed
- **Existing AWS Resources:**
  - ECS Clusters: `auth-cluster`, `pdf-cluster`, `fa-cluster`, `users-cluster`, `batch-cluster`
  - Task Definitions for each service
  - Target Groups (IP target type)
  - VPC with subnets and security groups

## 🚀 Quick Start

### 1. Clone and Install

```bash
cd start-engines-lambda

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure

Update `samconfig.toml` or set environment variables:

```bash
export SUBNETS="subnet-xxx,subnet-yyy"
export SECURITY_GROUPS="sg-xxx"
export USERS_TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/users-tg/xxx"
export BATCH_TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/batch-tg/xxx"
```

### 3. Deploy Both Lambdas

```bash
# Deploy Start Lambda
sam build
sam deploy --guided

# Deploy Stop Lambda
sam build --template template-stop.yaml
sam deploy \
    --template-file .aws-sam/build/template.yaml \
    --stack-name stop-engines-lambda-dev \
    --region us-east-2 \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides Environment=dev TaskSubnets="..." TaskSecurityGroups="..."
```

### 4. Test

```bash
# Start a service
./test-lambda.sh dev auth

# Stop all services
./stop-all-tasks.sh dev

# Or use EventBridge
aws events put-events --entries '[{
    "Source": "custom.app",
    "DetailType": "Start ECS Task",
    "Detail": "{\"service\":\"auth\"}"
}]'
```

## 📝 Event Format

### Simple Event (uses config defaults)
```json
{
  "source": "custom.app",
  "detail-type": "Start ECS Task",
  "detail": {
    "service": "auth"
  }
}
```

### Full Event (with overrides)
```json
{
  "source": "custom.app",
  "detail-type": "Start ECS Task",
  "detail": {
    "service": "auth",
    "cluster": "custom-cluster",
    "taskDefinition": "custom-task:5",
    "targetGroupArn": "arn:aws:elasticloadbalancing:...",
    "subnets": ["subnet-xxx"],
    "securityGroups": ["sg-xxx"],
    "port": 8080,
    "waitForHealthy": true
  }
}
```

### Supported Services
- `auth` - AuthAPI (port 8080)
- `pdf` - PDFCreator (port 9080)
- `fa` - FaEngine (port 2531)
- `users` - UserManagement (port 8080)
- `batch` - BatchEngineCall (port 8080)

## 📚 Documentation

### Quick Reference
- **[COMPLETE_PROJECT_SUMMARY.md](COMPLETE_PROJECT_SUMMARY.md)** - 🌟 **START HERE** - Complete overview
- **[START_STOP_COMPARISON.md](START_STOP_COMPARISON.md)** - Compare both lambdas and workflows
- **[QUICK_START_SUMMARY.md](QUICK_START_SUMMARY.md)** - Quick command reference

### Detailed Guides
- **[DEPLOYMENT_INSTRUCTIONS.md](DEPLOYMENT_INSTRUCTIONS.md)** - Step-by-step deployment guide
- **[STOP_LAMBDA_GUIDE.md](STOP_LAMBDA_GUIDE.md)** - Stop Lambda usage and scheduling
- **[COST_OPTIMIZATION_GUIDE.md](COST_OPTIMIZATION_GUIDE.md)** - Save $175/month with unified ALB
- **[UNIFIED_ALB_COMPLETE.md](UNIFIED_ALB_COMPLETE.md)** - Unified ALB migration guide
- **[SETUP_ECS_RESOURCES.md](SETUP_ECS_RESOURCES.md)** - ECS cluster setup
- **[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)** - Original implementation plan

## 🧪 Testing

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest --cov=. tests/ --cov-report=html

# Run specific test file
pytest tests/test_lambda_function.py -v
```

## 📊 Monitoring

### CloudWatch Logs
```bash
# Tail logs in real-time
aws logs tail /aws/lambda/start-engines-lambda-dev --follow

# Get recent errors
aws logs filter-log-events \
    --log-group-name /aws/lambda/start-engines-lambda-dev \
    --filter-pattern "ERROR"
```

### Check Task Status
```bash
# List running tasks
aws ecs list-tasks --cluster auth-cluster --desired-status RUNNING

# Check target health
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/auth-lb/0f8e49d7cd37c0c9
```

## 🔐 IAM Permissions Required

The Lambda execution role needs:
- **ECS**: `RunTask`, `DescribeTasks`, `DescribeTaskDefinition`, `StopTask`
- **ELB**: `RegisterTargets`, `DeregisterTargets`, `DescribeTargetHealth`
- **EC2**: `DescribeNetworkInterfaces`, `DescribeSubnets`, `DescribeSecurityGroups`
- **IAM**: `PassRole` (for task execution role)
- **Logs**: `CreateLogGroup`, `CreateLogStream`, `PutLogEvents`

See [iam-policy.json](iam-policy.json) for complete policy.

## 💰 Cost Optimization

### Infrastructure Savings (Unified ALB)
**Problem**: 5 separate ALBs = ~$200/month  
**Solution**: 1 ALB with path-based routing = ~$20/month  
**Savings**: **$175/month (87% reduction)**

### Task Management Savings (Stop Lambda)
**Problem**: ECS tasks running 24/7 = $150/month  
**Solution**: Auto-stop during off-hours (business hours only) = $42/month  
**Savings**: **$108/month (72% reduction)**

### Total Potential Savings: **$292/month = $3,504/year** 🎉

See [COST_OPTIMIZATION_GUIDE.md](COST_OPTIMIZATION_GUIDE.md) and [STOP_LAMBDA_GUIDE.md](STOP_LAMBDA_GUIDE.md) for details.

## 📁 Project Structure

```
start-engines-lambda/
├── 📄 START LAMBDA
│   ├── lambda_function.py          # Main start handler
│   ├── ecs_handler.py              # ECS task management
│   ├── target_group_handler.py     # Target group registration
│   ├── config.py                   # Service configuration
│   ├── template.yaml               # Start Lambda SAM template
│   └── deploy.sh                   # Start Lambda deployment
├── 📄 STOP LAMBDA
│   ├── stop_engines_lambda.py      # Main stop handler
│   ├── template-stop.yaml          # Stop Lambda SAM template
│   ├── deploy-stop-lambda.sh       # Stop Lambda deployment
│   └── stop-all-tasks.sh           # Stop Lambda test script
├── 📄 CONFIGURATION
│   ├── requirements.txt            # Python dependencies
│   ├── samconfig.toml              # SAM deployment config
│   ├── iam-policy.json             # IAM permissions
│   └── .gitignore                  # Git ignore rules
├── 📄 EXAMPLE EVENTS
│   ├── start-auth-task.json        # Start service examples
│   ├── stop-all-tasks.json         # Stop service examples
│   └── ...
├── 📄 TESTS
│   ├── tests/test_lambda_function.py
│   └── tests/test_config.py
└── 📄 DOCUMENTATION
    ├── README.md                   # This file
    ├── COMPLETE_PROJECT_SUMMARY.md # 🌟 START HERE
    ├── START_STOP_COMPARISON.md    # Compare both lambdas
    ├── STOP_LAMBDA_GUIDE.md        # Stop Lambda guide
    ├── COST_OPTIMIZATION_GUIDE.md  # ALB savings ($175/mo)
    ├── UNIFIED_ALB_COMPLETE.md     # Unified ALB setup
    ├── DEPLOYMENT_INSTRUCTIONS.md  # Deployment guide
    └── ... (see full list in COMPLETE_PROJECT_SUMMARY.md)
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_REGION` | AWS region | `us-east-2` |
| `SUBNETS` | Comma-separated subnet IDs | Required |
| `SECURITY_GROUPS` | Comma-separated SG IDs | Required |
| `LAUNCH_TYPE` | ECS launch type | `FARGATE` |
| `ASSIGN_PUBLIC_IP` | Assign public IP to tasks | `ENABLED` |
| `TASK_WAIT_TIMEOUT` | Max seconds to wait for task | `300` |
| `LOG_LEVEL` | Logging level | `INFO` |

Per-service overrides available for:
- `{SERVICE}_CLUSTER` - Cluster name
- `{SERVICE}_TASK_DEF` - Task definition
- `{SERVICE}_TARGET_GROUP_ARN` - Target group ARN
- `{SERVICE}_SUBNETS` - Service-specific subnets
- `{SERVICE}_SECURITY_GROUPS` - Service-specific security groups

## 🐛 Troubleshooting

### Task Fails to Start
- Check ECS cluster capacity
- Verify subnet IDs and security groups
- Check CloudWatch Logs for detailed error

### Target Registration Fails
- Verify target group ARN
- Ensure target type is `ip` (not `instance`)
- Check security group allows ALB → ECS traffic

### Health Check Fails
- Verify container exposes correct port
- Check health check path returns 200 OK
- Allow time for container initialization (30-60s)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

MIT License - feel free to use this project for any purpose.

## 🙋 Support

- **Issues**: Check CloudWatch Logs first
- **Documentation**: Review all .md files in project
- **AWS Status**: https://status.aws.amazon.com/

---

**Built for**: AuthAPI, PDFCreator, FaEngine, UserManagement, BatchEngineCall microservices  
**AWS Region**: us-east-2  
**Account**: 486151888818

