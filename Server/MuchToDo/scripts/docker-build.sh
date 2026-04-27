#!/bin/bash
set -e

echo "==> Building MuchToDo Docker image..."
cd "$(dirname "$0")/.."

export PATH=$PATH:/usr/local/go/bin:$(go env GOPATH)/bin

echo "==> Generating Swagger docs..."
swag init -g cmd/api/main.go

echo "==> Compiling Go binary..."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -p 1 \
    -ldflags="-w -s" \
    -o muchtodo \
    ./cmd/api/main.go

echo "==> Building Docker image..."
docker build -t muchtodo-backend:latest .

echo "==> Done! Image built successfully."
