#!/bin/bash
set -e

# ── Health Check ──────────────────────────────────────────────────────────────
# Usage: ./scripts/health-check.sh <alb-dns-name>

ALB_DNS=${1:-$ALB_DNS_NAME}
MAX_RETRIES=10
RETRY_INTERVAL=15

if [ -z "$ALB_DNS" ]; then
  ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names starttech-prod-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text)
fi

echo "Running health check against: http://$ALB_DNS/ping"

for i in $(seq 1 $MAX_RETRIES); do
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 5 \
    --max-time 10 \
    http://$ALB_DNS/ping)

  if [ "$RESPONSE" = "200" ]; then
    echo "Health check passed! (attempt $i/$MAX_RETRIES)"
    exit 0
  fi

  echo "Attempt $i/$MAX_RETRIES failed with HTTP $RESPONSE. Retrying in ${RETRY_INTERVAL}s..."
  sleep $RETRY_INTERVAL
done

echo "ERROR: Health check failed after $MAX_RETRIES attempts"
exit 1
