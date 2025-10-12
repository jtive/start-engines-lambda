# ECS Task Starter Lambda

A production-ready Python Lambda function that automatically starts ECS tasks and registers them with Application Load Balancer target groups when triggered by EventBridge events.

## ✨ Features

- 🚀 **Automatic ECS Task Management**: Starts tasks and waits for RUNNING state
- 🎯 **Target Group Registration**: Automatically registers tasks with ALB target groups
- 🔧 **Multi-Service Support**: Pre-configured for 5 microservices (AuthAPI, PDFCreator, FaEngine, UserManagement, BatchEngineCall)
- ⚙️ **Flexible Configuration**: Support for environment variables and event-level overrides
- 📊 **Comprehensive Logging**: CloudWatch integration with detailed execution logs
- 🧪 **Fully Tested**: Unit tests with mocked AWS services
- 💰 **Cost Optimized**: Includes guide to reduce ALB costs by 87%

## 🏗️ Architecture

```
EventBridge → Lambda → ECS (start task) → Wait for RUNNING → Get IP → Register with Target Group
```

This Lambda function:
1. ✅ Receives events from EventBridge (default event bus)
2. ✅ Starts exactly 1 ECS task in specified cluster
3. ✅ Waits for task to reach RUNNING state (with timeout)
4. ✅ Extracts task's private IP address (awsvpc mode)
5. ✅ Registers IP with specified target group
6. ✅ Returns detailed status including health check info

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

### 3. Deploy

```bash
# Build
sam build

# Deploy (first time with guided setup)
sam deploy --guided

# Or use deployment script
chmod +x deploy.sh
./deploy.sh dev
```

### 4. Test

```bash
# Test with CLI
chmod +x test-lambda.sh
./test-lambda.sh dev auth

# Or send EventBridge event
aws events put-events \
    --entries '[{
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

- **[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)** - Complete implementation plan and architecture decisions
- **[DEPLOYMENT_INSTRUCTIONS.md](DEPLOYMENT_INSTRUCTIONS.md)** - Step-by-step deployment guide
- **[COST_OPTIMIZATION_GUIDE.md](COST_OPTIMIZATION_GUIDE.md)** - Save $175/month by using single ALB with path routing

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

**Problem**: 5 separate ALBs = ~$200/month  
**Solution**: 1 ALB with path-based routing = ~$20/month  
**Savings**: **$175/month (87% reduction)**

See [COST_OPTIMIZATION_GUIDE.md](COST_OPTIMIZATION_GUIDE.md) for implementation details.

## 📁 Project Structure

```
start-engines-lambda/
├── lambda_function.py          # Main Lambda handler
├── ecs_handler.py              # ECS task management
├── target_group_handler.py     # Target group registration
├── config.py                   # Service configuration
├── requirements.txt            # Python dependencies
├── template.yaml               # SAM/CloudFormation template
├── iam-policy.json            # IAM permissions
├── deploy.sh                   # Deployment script
├── test-lambda.sh             # Testing script
├── tests/                      # Unit tests
│   ├── test_lambda_function.py
│   └── test_config.py
├── example-events/             # Sample EventBridge events
│   ├── start-auth-task.json
│   ├── start-pdf-task.json
│   └── start-fa-task.json
├── DEVELOPMENT_PLAN.md         # Implementation roadmap
├── DEPLOYMENT_INSTRUCTIONS.md  # Deployment guide
├── COST_OPTIMIZATION_GUIDE.md  # ALB cost savings
└── README.md                   # This file
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

