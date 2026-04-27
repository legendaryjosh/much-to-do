#!/bin/bash
set -e

echo "==> Starting MuchToDo with Docker Compose..."
cd "$(dirname "$0")/.."

if [ ! -f mongodb.key ]; then
    echo "==> Generating MongoDB keyfile..."
    openssl rand -base64 756 > mongodb.key
    sudo chown 999:999 mongodb.key
    chmod 400 mongodb.key
fi

if [ ! -f .env ]; then
    echo "==> .env file not found. Copying from .env.example..."
    cp .env.example .env
    echo "==> Please update .env with your values before continuing."
    exit 1
fi

docker compose up --build -d
echo "==> Services started! API available at http://localhost:8080"
echo "==> Health check: http://localhost:8080/health"
