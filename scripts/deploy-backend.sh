#!/bin/bash
set -e

# ── Deploy Backend to EC2 via Docker ─────────────────────────────────────────
# This script runs on each EC2 instance during ASG instance refresh
# IMAGE_URI_PLACEHOLDER is replaced by the CI/CD pipeline at deploy time

IMAGE_URI="IMAGE_URI_PLACEHOLDER"
AWS_REGION="us-east-1"
APP_NAME="muchtodo-api"

echo "Starting deployment of $IMAGE_URI"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $(echo $IMAGE_URI | cut -d'/' -f1)

# Pull latest image
echo "Pulling image..."
docker pull $IMAGE_URI

# Fetch secrets from SSM
MONGO_URI=$(aws ssm get-parameter \
  --name "/starttech/prod/mongo-uri" \
  --with-decryption \
  --query Parameter.Value \
  --output text)

REDIS_ADDR=$(aws ssm get-parameter \
  --name "/starttech/prod/redis-addr" \
  --query Parameter.Value \
  --output text)

JWT_SECRET=$(aws ssm get-parameter \
  --name "/starttech/prod/jwt-secret" \
  --with-decryption \
  --query Parameter.Value \
  --output text)

# Stop and remove existing container
echo "Stopping existing container..."
docker stop $APP_NAME 2>/dev/null || true
docker rm $APP_NAME 2>/dev/null || true

# Run new container
echo "Starting new container..."
docker run -d \
  --name $APP_NAME \
  --restart unless-stopped \
  -p 8080:8080 \
  -e PORT=8080 \
  -e MONGO_URI="$MONGO_URI" \
  -e DB_NAME="muchtodo" \
  -e REDIS_ADDR="$REDIS_ADDR" \
  -e ENABLE_CACHE=true \
  -e JWT_SECRET_KEY="$JWT_SECRET" \
  -e JWT_EXPIRATION_HOURS=72 \
  -e LOG_LEVEL=info \
  -e LOG_FORMAT=json \
  $IMAGE_URI

echo "Waiting for container to be healthy..."
sleep 10

# Quick health check
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ping)
if [ "$RESPONSE" = "200" ]; then
  echo "Deployment successful! Container is healthy."
else
  echo "ERROR: Health check failed with HTTP $RESPONSE"
  docker logs $APP_NAME
  exit 1
fi

# Clean up old images
docker image prune -f

echo "Done!"
