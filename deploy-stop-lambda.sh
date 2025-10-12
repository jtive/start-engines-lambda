#!/bin/bash
# Deployment script for Stop Engines Lambda

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENVIRONMENT=${1:-dev}
STACK_NAME="stop-engines-lambda-${ENVIRONMENT}"
REGION=${AWS_REGION:-us-east-2}

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Stop ECS Tasks Lambda Deployment${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Region: ${YELLOW}${REGION}${NC}"
echo -e "Stack Name: ${YELLOW}${STACK_NAME}${NC}"
echo ""

# Build
echo -e "${GREEN}Building Lambda function...${NC}"
sam build --template template-stop.yaml

# Deploy
echo -e "${GREEN}Deploying Lambda function...${NC}"
sam deploy \
    --template-file .aws-sam/build/template.yaml \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        Environment="${ENVIRONMENT}" \
        TaskSubnets="subnet-00347cba6de355f15,subnet-0c28cf78daa71a342,subnet-0e4374ad2092dee14" \
        TaskSecurityGroups="sg-0375466cf9847b96d" \
        UsersTargetGroupArn="arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/users-tg/f9a22b2edc13281f" \
        BatchTargetGroupArn="arn:aws:elasticloadbalancing:us-east-2:486151888818:targetgroup/batch-tg/4016a351002f823f" \
    --no-fail-on-empty-changeset

echo ""
echo -e "${GREEN}Deployment successful!${NC}"
echo ""
echo -e "${GREEN}Stack Outputs:${NC}"
aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "1. Test stopping all tasks:"
echo -e "   ${YELLOW}./stop-all-tasks.sh${NC}"
echo ""
echo -e "2. Monitor logs:"
echo -e "   ${YELLOW}aws logs tail /aws/lambda/${STACK_NAME} --follow${NC}"
echo ""

