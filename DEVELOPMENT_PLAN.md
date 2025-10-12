# Development Plan: ECS Task Starter Lambda

## Project Overview
Create a Python Lambda function that:
1. Consumes messages from AWS EventBridge (default event bus)
2. Starts a single task in an ECS cluster
3. Updates the associated Application Load Balancer (ALB) target group to register the new task

## Architecture

```
EventBridge (Default Event Bus)
    ↓ (Event Rule)
Lambda Function (Python 3.12)
    ↓
    ├─→ ECS: Start Task
    └─→ ELB: Register Target with Target Group
```

## Prerequisites

### AWS Resources Required
- **ECS Cluster**: Existing cluster where tasks will run
- **ECS Task Definition**: Defines the container(s) to run
- **Target Group**: ALB/NLB target group for health checks and routing
- **VPC & Subnets**: For task network configuration (if using awsvpc mode)
- **Security Groups**: For task network access
- **EventBridge Rule**: To trigger the Lambda on specific events

### Development Tools
- Python 3.9+ (Lambda runtime: 3.12 recommended)
- AWS CLI configured
- boto3 library
- Docker (optional, for local testing with SAM)

## Implementation Steps

### Phase 1: Project Setup
- [x] Create project directory structure
- [ ] Set up Python virtual environment
- [ ] Create requirements.txt
- [ ] Create Lambda function handler
- [ ] Create configuration file for environment variables

### Phase 2: Lambda Function Development
- [ ] Implement EventBridge event parser
- [ ] Implement ECS task starter logic
  - Extract cluster name, task definition from event/config
  - Handle network configuration (subnets, security groups)
  - Start the ECS task
  - Wait for task to reach RUNNING state
  - Extract task network interface details
- [ ] Implement target group updater logic
  - Get task's private IP address
  - Register target with target group
  - Handle port mapping
- [ ] Add error handling and logging
- [ ] Add input validation

### Phase 3: IAM Permissions
Create IAM role with policies for:
- [ ] ECS permissions
  - `ecs:RunTask`
  - `ecs:DescribeTasks`
  - `ecs:DescribeTaskDefinition`
- [ ] ELB permissions
  - `elasticloadbalancing:RegisterTargets`
  - `elasticloadbalancing:DescribeTargetHealth`
- [ ] IAM permission (if using task execution role)
  - `iam:PassRole`
- [ ] EC2 permissions (for network interface details)
  - `ec2:DescribeNetworkInterfaces`
- [ ] CloudWatch Logs
  - `logs:CreateLogGroup`
  - `logs:CreateLogStream`
  - `logs:PutLogEvents`

### Phase 4: Infrastructure as Code
- [ ] Create CloudFormation/Terraform/SAM template
  - Lambda function
  - IAM roles and policies
  - EventBridge rule
  - Environment variables
- [ ] Add deployment scripts

### Phase 5: Testing
- [ ] Unit tests for event parsing
- [ ] Unit tests for ECS task starter
- [ ] Unit tests for target group registration
- [ ] Integration test with mock AWS services (moto)
- [ ] Manual testing in AWS environment

### Phase 6: Deployment & Monitoring
- [ ] Deploy to development environment
- [ ] Set up CloudWatch alarms
  - Lambda errors
  - Lambda duration
  - ECS task start failures
- [ ] Test end-to-end flow
- [ ] Deploy to production
- [ ] Document operational procedures

## Technical Considerations

### 1. ECS Task Network Modes
The implementation differs based on network mode:

**awsvpc (Fargate/EC2)**
- Task gets its own ENI with private IP
- Register the task's private IP to target group
- Most common for modern deployments

**bridge/host (EC2 only)**
- Register the EC2 instance IP with dynamic port
- Need to query task for port mappings

### 2. Target Group Registration
- **For IP targets**: Register task's private IP with target port
- **For instance targets**: Register EC2 instance ID with dynamic port
- Must wait for task to be RUNNING before getting IP details

### 3. Timing Considerations
- Task startup time varies (15s - 2min+)
- Target group health checks take time
- Consider implementing:
  - Polling with timeout
  - Async processing
  - Dead letter queue for failures

### 4. Event Structure
EventBridge event should contain:
```json
{
  "source": "custom.source",
  "detail-type": "Start ECS Task",
  "detail": {
    "cluster": "my-cluster",
    "taskDefinition": "my-task:1",
    "targetGroupArn": "arn:aws:elasticloadbalancing:...",
    "subnets": ["subnet-xxx"],
    "securityGroups": ["sg-xxx"],
    "port": 8080
  }
}
```

### 5. Error Scenarios to Handle
- Task fails to start (resource constraints)
- Task crashes immediately
- Network issues preventing registration
- Target group health check failures
- Permission errors

## File Structure
```
start-engines-lambda/
├── lambda_function.py          # Main Lambda handler
├── ecs_handler.py              # ECS task management logic
├── target_group_handler.py     # Target group registration logic
├── config.py                   # Configuration management
├── requirements.txt            # Python dependencies
├── tests/                      # Unit and integration tests
│   ├── test_lambda_function.py
│   ├── test_ecs_handler.py
│   └── test_target_group_handler.py
├── template.yaml               # SAM/CloudFormation template
├── deploy.sh                   # Deployment script
├── README.md                   # Project documentation
└── DEVELOPMENT_PLAN.md         # This file
```

## Configuration Options

### Environment Variables
- `ECS_CLUSTER` - Default ECS cluster name
- `TASK_DEFINITION` - Default task definition ARN
- `TARGET_GROUP_ARN` - Default target group ARN
- `SUBNETS` - Comma-separated subnet IDs
- `SECURITY_GROUPS` - Comma-separated security group IDs
- `CONTAINER_PORT` - Port the container listens on
- `TASK_WAIT_TIMEOUT` - Max seconds to wait for task (default: 300)
- `LOG_LEVEL` - Logging level (default: INFO)

## Success Metrics
- Lambda execution time < 30 seconds (excluding task startup)
- 99% success rate for task starts
- Tasks registered with target group within 60 seconds
- Zero cold start issues affecting critical path

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Task fails to start | High | Implement retry logic, alerting |
| Long task startup time | Medium | Set appropriate timeout, async processing |
| Target health check fails | High | Validate health check path, add debugging |
| Lambda timeout | Medium | Set Lambda timeout > expected duration |
| Permission errors | High | Test IAM permissions thoroughly |
| Event format changes | Medium | Validate event schema, version events |

## Next Steps
1. Review and approve this plan
2. Begin Phase 1: Project Setup
3. Implement core Lambda function (Phase 2)
4. Create IAM roles and test permissions (Phase 3)
5. Deploy and test in development environment

## Questions to Clarify
1. **Launch Type**: Are you using Fargate or EC2 for ECS?
2. **Network Mode**: What network mode is your task definition using?
3. **Target Type**: Is your target group configured for IP or instance targets?
4. **Event Source**: What events should trigger this Lambda? (Custom app events, scheduled, etc.)
5. **Scaling**: Do you need to start multiple tasks or always just 1?
6. **Existing Resources**: Do you have the ECS cluster, task definition, and target group already created?

