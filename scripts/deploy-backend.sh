#!/bin/bash
set -e

IMAGE_URI="IMAGE_URI_PLACEHOLDER"
AWS_REGION="us-east-1"
APP_NAME="muchtodo-api"

echo "Starting deployment of $IMAGE_URI"

# Install Docker first
yum install -y docker
systemctl enable docker
systemctl start docker
sleep 15

# Install AWS CLI
yum install -y aws-cli

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $(echo $IMAGE_URI | cut -d'/' -f1)

echo "Pulling image..."
docker pull $IMAGE_URI

# Fetch mongo URI
RAW_MONGO=$(aws ssm get-parameter \
  --name "/starttech/prod/mongo-uri" \
  --with-decryption \
  --query Parameter.Value \
  --output text --region $AWS_REGION)

echo "DEBUG - First 30 chars: ${RAW_MONGO:0:30}"
echo "DEBUG - URI length: ${#RAW_MONGO}"

# Fetch JWT secret
RAW_JWT=$(aws ssm get-parameter \
  --name "/starttech/prod/jwt-secret" \
  --with-decryption \
  --query Parameter.Value \
  --output text --region $AWS_REGION)

# Stop existing container
docker stop $APP_NAME 2>/dev/null || true
docker rm $APP_NAME 2>/dev/null || true

# Run container passing env vars directly
echo "Starting container..."
docker run -d \
  --name $APP_NAME \
  --restart on-failure:3 \
  -p 8080:8080 \
  -e PORT=8080 \
  -e "MONGO_URI=${RAW_MONGO}" \
  -e DB_NAME=much_todo_db \
  -e ENABLE_CACHE=false \
  -e "JWT_SECRET_KEY=${RAW_JWT}" \
  -e JWT_EXPIRATION_HOURS=72 \
  -e LOG_LEVEL=info \
  -e LOG_FORMAT=json \
  $IMAGE_URI

echo "Waiting 60 seconds for app to start..."
sleep 60

echo "Container logs:"
docker logs $APP_NAME --tail 30

# Health check
for i in $(seq 1 10); do
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    http://localhost:8080/ping 2>/dev/null || echo "000")
  echo "Health check attempt $i: HTTP $RESPONSE"
  if [ "$RESPONSE" = "200" ]; then
    echo "Health check passed!"
    exit 0
  fi
  sleep 10
done

echo "Health check failed - showing final logs:"
docker logs $APP_NAME --tail 50
exit 1
