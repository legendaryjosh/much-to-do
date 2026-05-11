#!/bin/bash
set -e

# ── Rollback ──────────────────────────────────────────────────────────────────
# Usage: ./scripts/rollback.sh <previous-image-uri>

PREVIOUS_IMAGE=${1}
ASG_NAME="starttech-prod-asg"
AWS_REGION="us-east-1"

if [ -z "$PREVIOUS_IMAGE" ]; then
  echo "ERROR: Previous image URI is required"
  echo "Usage: $0 <previous-image-uri>"
  exit 1
fi

echo "Rolling back to: $PREVIOUS_IMAGE"

# Update launch template to previous image
aws ec2 create-launch-template-version \
  --launch-template-name starttech-prod-api \
  --source-version '$Latest' \
  --launch-template-data "{
    \"UserData\": \"$(cat scripts/deploy-backend.sh | \
      sed "s|IMAGE_URI_PLACEHOLDER|$PREVIOUS_IMAGE|g" | \
      base64 -w 0)\"
  }" \
  --region $AWS_REGION

echo "Triggering ASG instance refresh for rollback..."
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name $ASG_NAME \
  --preferences '{
    "MinHealthyPercentage": 50,
    "InstanceWarmup": 60
  }' \
  --region $AWS_REGION

echo "Rollback initiated! Monitor progress with:"
echo "aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME"
