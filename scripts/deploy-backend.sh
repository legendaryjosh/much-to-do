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

# Fetch mongo URI and debug
RAW_MONGO=$(aws ssm get-parameter \
  --name "/starttech/prod/mongo-uri" \
  --with-decryption \
  --query Parameter.Value \
  --output text --region $AWS_REGION)

echo "DEBUG - First 20 chars of MONGO_URI: ${RAW_MONGO:0:20}"
echo "DEBUG - URI length: ${#RAW_MONGO}"

# Write to env file
printf "PORT=8080\n" > /tmp/app.env
printf "MONGO_URI=%s\n" "$RAW_MONGO" >> /tmp/app.env
printf "DB_NAME=much_todo_db\n" >> /tmp/app.env
printf "ENABLE_CACHE=false\n" >> /tmp/app.env
printf "JWT_EXPIRATION_HOURS=72\n" >> /tmp/app.env
printf "LOG_LEVEL=info\n" >> /tmp/app.env
printf "LOG_FORMAT=json\n" >> /tmp/app.env

# Fetch JWT secret
RAW_JWT=$(aws ssm get-parameter \
  --name "/starttech/prod/jwt-secret" \
  --with-decryption \
  --query Parameter.Value \
  --output text --region $AWS_REGION)
printf "JWT_SECRET_KEY=%s\n" "$RAW_JWT" >> /tmp/app.env

echo "DEBUG - env file contents (first line only):"
head -2 /tmp/app.env

# Stop existing container
docker stop $APP_NAME 2>/dev/null || true
docker rm $APP_NAME 2>/dev/null || true

echo "Starting container..."
docker run -d \
  --name $APP_NAME \
  --restart on-failure:3 \
  --env-file /tmp/app.env \
  -p 8080:8080 \
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
    rm -f /tmp/mongo_uri.txt /tmp/jwt_secret.txt /tmp/app.env
    exit 0
  fi
  sleep 10
done

echo "Health check failed - showing final logs:"
docker logs $APP_NAME --tail 50
rm -f /tmp/app.env
exit 1
