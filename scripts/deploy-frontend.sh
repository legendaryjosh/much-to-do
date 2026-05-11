#!/bin/bash
set -e

# ── Deploy Frontend to S3 ─────────────────────────────────────────────────────
# Usage: ./scripts/deploy-frontend.sh <s3-bucket-name> <cloudfront-distribution-id>

S3_BUCKET=${1:-$S3_BUCKET_NAME}
CF_DIST_ID=${2:-$CLOUDFRONT_DISTRIBUTION_ID}

if [ -z "$S3_BUCKET" ] || [ -z "$CF_DIST_ID" ]; then
  echo "ERROR: S3 bucket and CloudFront distribution ID are required"
  echo "Usage: $0 <s3-bucket> <cloudfront-dist-id>"
  exit 1
fi

echo "Building React app..."
cd Client
npm ci
npm run build
cd ..

echo "Syncing to S3 bucket: $S3_BUCKET"
aws s3 sync Client/dist/ s3://$S3_BUCKET/ \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html"

aws s3 cp Client/dist/index.html s3://$S3_BUCKET/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

echo "Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id $CF_DIST_ID \
  --paths "/*"

echo "Frontend deployed successfully!"
