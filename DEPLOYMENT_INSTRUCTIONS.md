# Deployment Instructions

## Prerequisites

Before deploying, ensure you have:

1. **AWS CLI** installed and configured
   ```bash
   aws --version
   aws configure
   ```

2. **AWS SAM CLI** installed
   ```bash
   pip install aws-sam-cli
   sam --version
   ```

3. **Python 3.12** installed
   ```bash
   python --version
   ```

4. **AWS Resources Created:**
   - ECS Clusters (auth-cluster, pdf-cluster, fa-cluster, users-cluster, batch-cluster)
   - Task Definitions for each service
   - Target Groups (3 existing + 2 new ones)
   - VPC with subnets and security groups
   - IAM permissions to create Lambda functions and roles

---

## Step 1: Prepare Configuration

### 1.1 Get Your Subnet IDs

```bash
aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=YOUR_VPC_ID" \
    --query "Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]" \
    --output table
```

Note down 2-3 subnet IDs (preferably in different AZs).

### 1.2 Get Your Security Group IDs

```bash
aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=YOUR_VPC_ID" \
    --query "SecurityGroups[*].[GroupId,GroupName,Description]" \
    --output table
```

Note down the security group ID for your ECS tasks.

### 1.3 Create Missing Target Groups (Users & Batch)

```bash
# Users Target Group
aws elbv2 create-target-group \
    --name users-tg \
    --protocol HTTP \
    --port 8080 \
    --vpc-id YOUR_VPC_ID \
    --target-type ip \
    --health-check-path /health \
    --health-check-interval-seconds 30

# Batch Target Group
aws elbv2 create-target-group \
    --name batch-tg \
    --protocol HTTP \
    --port 8080 \
    --vpc-id YOUR_VPC_ID \
    --target-type ip \
    --health-check-path /health \
    --health-check-interval-seconds 30
```

Note down the ARNs of the created target groups.

---

## Step 2: Update Configuration

### 2.1 Create `samconfig.toml`

Create this file in the project root:

```toml
version = 0.1

[default]
[default.deploy]
[default.deploy.parameters]
stack_name = "start-engines-lambda-dev"
s3_bucket = "YOUR_SAM_DEPLOYMENT_BUCKET"  # Optional
s3_prefix = "start-engines-lambda"
region = "us-east-2"
capabilities = "CAPABILITY_NAMED_IAM"
parameter_overrides = [
    "Environment=dev",
    "TaskSubnets=subnet-xxx,subnet-yyy,subnet-zzz",  # Replace with your subnet IDs
    "TaskSecurityGroups=sg-xxx",  # Replace with your security group ID
    "UsersTargetGroupArn=arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/users-tg/xxx",  # Replace
    "BatchTargetGroupArn=arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/batch-tg/xxx",  # Replace
]
confirm_changeset = true
resolve_s3 = true
```

### 2.2 Update `config.py` (if needed)

If your cluster names or task definition names differ from defaults, you can:
- Either update the defaults in `config.py`
- Or set environment variables in the SAM template
- Or override via EventBridge events

---

## Step 3: Deploy

### 3.1 Build the Lambda

```bash
sam build
```

This will:
- Package Python dependencies from `requirements.txt`
- Prepare Lambda deployment package

### 3.2 Deploy with SAM

**First time deployment (guided):**
```bash
sam deploy --guided
```

This will prompt you for:
- Stack name
- Region
- Parameters (subnets, security groups, target groups)
- Capabilities (CAPABILITY_NAMED_IAM)

**Subsequent deployments:**
```bash
sam deploy
```

### 3.3 Alternative: Use Deployment Script

```bash
chmod +x deploy.sh
./deploy.sh dev
```

---

## Step 4: Verify Deployment

### 4.1 Check Stack Status

```bash
aws cloudformation describe-stacks \
    --stack-name start-engines-lambda-dev \
    --query "Stacks[0].StackStatus"
```

Should show: `CREATE_COMPLETE` or `UPDATE_COMPLETE`

### 4.2 Get Lambda Function ARN

```bash
aws cloudformation describe-stacks \
    --stack-name start-engines-lambda-dev \
    --query "Stacks[0].Outputs"
```

### 4.3 Check EventBridge Rule

```bash
aws events list-rules \
    --name-prefix start-engines-lambda
```

---

## Step 5: Test the Lambda

### 5.1 Using AWS Console

1. Go to Lambda → Functions → `start-engines-lambda-dev`
2. Click "Test" tab
3. Create a test event with this JSON:
   ```json
   {
     "source": "custom.app",
     "detail-type": "Start ECS Task",
     "detail": {
       "service": "auth"
     }
   }
   ```
4. Click "Test"
5. Check execution results and logs

### 5.2 Using CLI

```bash
chmod +x test-lambda.sh
./test-lambda.sh dev auth
```

Or manually:

```bash
aws lambda invoke \
    --function-name start-engines-lambda-dev \
    --payload file://example-events/start-auth-task.json \
    --region us-east-2 \
    response.json

cat response.json | python -m json.tool
```

### 5.3 Using EventBridge

Send a test event:

```bash
aws events put-events \
    --entries '[{
        "Source": "custom.app",
        "DetailType": "Start ECS Task",
        "Detail": "{\"service\":\"auth\"}"
    }]'
```

---

## Step 6: Monitor

### 6.1 CloudWatch Logs

```bash
# Tail logs in real-time
aws logs tail /aws/lambda/start-engines-lambda-dev --follow

# Get recent logs
aws logs tail /aws/lambda/start-engines-lambda-dev --since 10m
```

### 6.2 Check ECS Tasks

```bash
# List running tasks in auth cluster
aws ecs list-tasks --cluster auth-cluster --desired-status RUNNING

# Describe a task
aws ecs describe-tasks \
    --cluster auth-cluster \
    --tasks TASK_ARN
```

### 6.3 Check Target Group Health

```bash
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/auth-lb/0f8e49d7cd37c0c9
```

---

## Step 7: Trigger from Your Application

### Option A: From .NET Application

```csharp
using Amazon.EventBridge;
using Amazon.EventBridge.Model;

var client = new AmazonEventBridgeClient();

var request = new PutEventsRequest
{
    Entries = new List<PutEventsRequestEntry>
    {
        new PutEventsRequestEntry
        {
            Source = "custom.app",
            DetailType = "Start ECS Task",
            Detail = @"{
                ""service"": ""auth""
            }"
        }
    }
};

var response = await client.PutEventsAsync(request);
```

### Option B: From AWS CLI

```bash
aws events put-events \
    --entries '[{
        "Source": "custom.app",
        "DetailType": "Start ECS Task",
        "Detail": "{\"service\":\"pdf\"}"
    }]'
```

### Option C: Scheduled (Cron)

Add to `template.yaml`:

```yaml
Events:
  ScheduledStartAuth:
    Type: Schedule
    Properties:
      Schedule: cron(0 8 * * ? *)  # Every day at 8 AM UTC
      Input: '{"detail": {"service": "auth"}}'
```

---

## Troubleshooting

### Issue: "ValidationError: Subnet not found"

**Solution**: Verify subnet IDs are correct and in the same region

```bash
aws ec2 describe-subnets --subnet-ids subnet-xxx
```

### Issue: "AccessDeniedException: User is not authorized"

**Solution**: Ensure your IAM user has permissions to:
- Create CloudFormation stacks
- Create Lambda functions
- Create IAM roles
- Create EventBridge rules

### Issue: "Task failed to start - resource:CPU unavailable"

**Solution**: 
- Check ECS cluster capacity
- If using Fargate, ensure cluster has capacity provider
- Check service quotas

### Issue: "TargetGroup not found"

**Solution**: Verify target group ARNs are correct

```bash
aws elbv2 describe-target-groups --names auth-lb pdf-lb fa2-tg
```

### Issue: "Task starts but health check fails"

**Solution**:
- Verify container exposes correct port
- Check security group allows ALB → ECS traffic
- Verify health check path returns 200 OK
- Check container logs in CloudWatch

```bash
aws ecs describe-tasks \
    --cluster auth-cluster \
    --tasks TASK_ARN \
    --query "tasks[0].containers[0].{name:name,status:lastStatus,reason:reason}"
```

---

## Updating the Lambda

### Update Code Only

```bash
sam build
sam deploy
```

### Update Configuration

Edit `samconfig.toml` or `template.yaml`, then:

```bash
sam deploy
```

### Rollback

```bash
aws cloudformation rollback-stack --stack-name start-engines-lambda-dev
```

---

## Clean Up (Delete Resources)

### Delete the Stack

```bash
aws cloudformation delete-stack --stack-name start-engines-lambda-dev
```

### Wait for Deletion

```bash
aws cloudformation wait stack-delete-complete --stack-name start-engines-lambda-dev
```

---

## Production Deployment Checklist

- [ ] Update environment to `prod`
- [ ] Review IAM permissions (least privilege)
- [ ] Set up CloudWatch alarms
- [ ] Configure dead letter queue (DLQ)
- [ ] Enable X-Ray tracing
- [ ] Set up log retention policy
- [ ] Document runbooks
- [ ] Test rollback procedures
- [ ] Set up monitoring dashboard
- [ ] Configure SNS notifications for failures

---

## Next Steps

After successful deployment:

1. ✅ Review [COST_OPTIMIZATION_GUIDE.md](COST_OPTIMIZATION_GUIDE.md) for ALB cost savings
2. ✅ Set up monitoring and alerts
3. ✅ Integrate with your CI/CD pipeline
4. ✅ Test all 5 services
5. ✅ Document operational procedures

---

## Support

For issues or questions:
1. Check CloudWatch Logs: `/aws/lambda/start-engines-lambda-dev`
2. Review this documentation
3. Check AWS service status: https://status.aws.amazon.com/

