#!/bin/bash
# Deployment script for ECS Task Starter Lambda

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-dev}
STACK_NAME="start-engines-lambda-${ENVIRONMENT}"
REGION=${AWS_REGION:-us-east-2}
S3_BUCKET=${SAM_DEPLOYMENT_BUCKET:-}

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}ECS Task Starter Lambda Deployment${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Region: ${YELLOW}${REGION}${NC}"
echo -e "Stack Name: ${YELLOW}${STACK_NAME}${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi

# Check SAM CLI
if ! command -v sam &> /dev/null; then
    echo -e "${RED}Error: SAM CLI not found. Please install SAM CLI.${NC}"
    echo -e "${YELLOW}Install with: pip install aws-sam-cli${NC}"
    exit 1
fi

# Validate AWS credentials
echo -e "${GREEN}Validating AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "AWS Account: ${YELLOW}${ACCOUNT_ID}${NC}"
echo ""

# Check if S3 bucket is specified, if not prompt
if [ -z "$S3_BUCKET" ]; then
    echo -e "${YELLOW}No S3 bucket specified for deployment artifacts.${NC}"
    echo -e "SAM will use a managed bucket or you can specify one."
    echo ""
fi

# Run SAM build
echo -e "${GREEN}Building Lambda function...${NC}"
sam build --use-container

# Run SAM deploy
echo -e "${GREEN}Deploying Lambda function...${NC}"
if [ -n "$S3_BUCKET" ]; then
    sam deploy \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --s3-bucket "${S3_BUCKET}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameter-overrides \
            Environment="${ENVIRONMENT}" \
        --no-fail-on-empty-changeset
else
    sam deploy \
        --stack-name "${STACK_NAME}" \
        --region "${REGION}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --parameter-overrides \
            Environment="${ENVIRONMENT}" \
        --guided \
        --no-fail-on-empty-changeset
fi

# Get outputs
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
echo -e "1. Update the Lambda environment variables with your actual:"
echo -e "   - Subnet IDs"
echo -e "   - Security Group IDs"
echo -e "   - Target Group ARNs (for users and batch services)"
echo ""
echo -e "2. Test the Lambda with an EventBridge test event:"
echo -e "   ${YELLOW}./test-lambda.sh${NC}"
echo ""
echo -e "3. Monitor logs:"
echo -e "   ${YELLOW}aws logs tail /aws/lambda/${STACK_NAME} --follow${NC}"
echo ""

