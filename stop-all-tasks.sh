#!/bin/bash
# Script to stop all ECS tasks

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ENVIRONMENT=${1:-dev}
FUNCTION_NAME="stop-engines-lambda-${ENVIRONMENT}"
REGION=${AWS_REGION:-us-east-2}

echo -e "${GREEN}Stopping All ECS Tasks${NC}"
echo -e "Function: ${YELLOW}${FUNCTION_NAME}${NC}"
echo -e "Region: ${YELLOW}${REGION}${NC}"
echo ""

# Create event to stop all services
cat > /tmp/stop-all-event.json <<EOF
{
  "source": "custom.app",
  "detail-type": "Stop ECS Tasks",
  "detail": {
    "services": [],
    "deregister_targets": true
  }
}
EOF

echo -e "${GREEN}Stopping all ECS tasks...${NC}"
aws lambda invoke \
    --function-name "${FUNCTION_NAME}" \
    --payload file:///tmp/stop-all-event.json \
    --region "${REGION}" \
    /tmp/stop-response.json

echo ""
echo -e "${GREEN}Response:${NC}"
cat /tmp/stop-response.json | python3 -m json.tool

# Clean up
rm /tmp/stop-all-event.json /tmp/stop-response.json

echo ""
echo -e "${GREEN}✓ All tasks stopped!${NC}"
echo -e "${YELLOW}Check CloudWatch Logs for details:${NC}"
echo -e "${YELLOW}aws logs tail /aws/lambda/${FUNCTION_NAME} --follow --region ${REGION}${NC}"

