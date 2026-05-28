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

# Fetch secrets from SSM
MONGO_URI=$(aws ssm get-parameter \
  --name "/starttech/prod/mongo-uri" \
  --with-decryption \
  --query Parameter.Value \
  --output text --region $AWS_REGION)

JWT_SECRET=$(aws ssm get-parameter \
  --name "/starttech/prod/jwt-secret" \
  --with-decryption \
  --query Parameter.Value \
  --output text --region $AWS_REGION)

# Stop existing container
docker stop $APP_NAME 2>/dev/null || true
docker rm $APP_NAME 2>/dev/null || true

# Run new container WITHOUT Redis first
echo "Starting container..."
docker run -d \
  --name $APP_NAME \
  --restart on-failure:3 \
  -p 8080:8080 \
  -e PORT=8080 \
  -e MONGO_URI="$MONGO_URI" \
  -e DB_NAME="much_todo_db" \
  -e ENABLE_CACHE=false \
  -e JWT_SECRET_KEY="$JWT_SECRET" \
  -e JWT_EXPIRATION_HOURS=72 \
  -e LOG_LEVEL=info \
  -e LOG_FORMAT=json \
  $IMAGE_URI

echo "Waiting for container to start..."
sleep 30

# Check container is running
if docker ps | grep -q $APP_NAME; then
  echo "Container is running!"
  docker logs $APP_NAME --tail 20
else
  echo "Container failed to start!"
  docker logs $APP_NAME
  exit 1
fi

# Health check
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ping)
if [ "$RESPONSE" = "200" ]; then
  echo "Health check passed!"
else
  echo "Health check failed with HTTP $RESPONSE"
  docker logs $APP_NAME
  exit 1
fi

echo "Done!"
