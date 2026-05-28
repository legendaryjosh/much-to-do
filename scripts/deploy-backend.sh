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

# Fetch secrets from SSM into files to avoid shell interpretation issues
aws ssm get-parameter \
  --name "/starttech/prod/mongo-uri" \
  --with-decryption \
  --query Parameter.Value \
  --output text --region $AWS_REGION > /tmp/mongo_uri.txt

aws ssm get-parameter \
  --name "/starttech/prod/jwt-secret" \
  --with-decryption \
  --query Parameter.Value \
  --output text --region $AWS_REGION > /tmp/jwt_secret.txt

echo "Mongo URI fetched: $(cat /tmp/mongo_uri.txt | cut -c1-30)..."

# Stop existing container
docker stop $APP_NAME 2>/dev/null || true
docker rm $APP_NAME 2>/dev/null || true

# Run new container using env file
cat > /tmp/app.env << ENVEOF
PORT=8080
MONGO_URI=$(cat /tmp/mongo_uri.txt)
DB_NAME=much_todo_db
ENABLE_CACHE=false
JWT_SECRET_KEY=$(cat /tmp/jwt_secret.txt)
JWT_EXPIRATION_HOURS=72
LOG_LEVEL=info
LOG_FORMAT=json
ENVEOF

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
    # Cleanup sensitive files
    rm -f /tmp/mongo_uri.txt /tmp/jwt_secret.txt /tmp/app.env
    exit 0
  fi
  sleep 10
done

echo "Health check failed - showing final logs:"
docker logs $APP_NAME --tail 50
rm -f /tmp/mongo_uri.txt /tmp/jwt_secret.txt /tmp/app.env
exit 1
