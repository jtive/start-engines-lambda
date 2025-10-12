#!/bin/bash
# Test script for ECS Task Starter Lambda

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENVIRONMENT=${1:-dev}
SERVICE=${2:-auth}
FUNCTION_NAME="start-engines-lambda-${ENVIRONMENT}"
REGION=${AWS_REGION:-us-east-2}

echo -e "${GREEN}Testing Lambda Function${NC}"
echo -e "Function: ${YELLOW}${FUNCTION_NAME}${NC}"
echo -e "Service: ${YELLOW}${SERVICE}${NC}"
echo -e "Region: ${YELLOW}${REGION}${NC}"
echo ""

# Create test event
cat > /tmp/test-event.json <<EOF
{
  "source": "custom.app",
  "detail-type": "Start ECS Task",
  "detail": {
    "service": "${SERVICE}"
  }
}
EOF

echo -e "${GREEN}Test Event:${NC}"
cat /tmp/test-event.json
echo ""

# Invoke Lambda
echo -e "${GREEN}Invoking Lambda...${NC}"
aws lambda invoke \
    --function-name "${FUNCTION_NAME}" \
    --payload file:///tmp/test-event.json \
    --region "${REGION}" \
    /tmp/lambda-response.json

echo ""
echo -e "${GREEN}Response:${NC}"
cat /tmp/lambda-response.json | python3 -m json.tool

# Clean up
rm /tmp/test-event.json /tmp/lambda-response.json

echo ""
echo -e "${GREEN}Check CloudWatch Logs for details:${NC}"
echo -e "${YELLOW}aws logs tail /aws/lambda/${FUNCTION_NAME} --follow --region ${REGION}${NC}"

