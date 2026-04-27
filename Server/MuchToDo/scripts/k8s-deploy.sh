#!/bin/bash
set -e

echo "==> Deploying MuchToDo to Kubernetes..."
cd "$(dirname "$0")/.."

echo "==> Loading Docker image into Kind cluster..."
kind load docker-image muchtodo-backend:latest --name muchtodo-cluster

echo "==> Applying Kubernetes manifests..."
kubectl apply -f kubernetes/namespace.yaml

kubectl apply -f kubernetes/mongodb/mongodb-secret.yaml
kubectl apply -f kubernetes/mongodb/mongodb-configmap.yaml
kubectl apply -f kubernetes/mongodb/mongodb-pvc.yaml
kubectl apply -f kubernetes/mongodb/mongodb-deployment.yaml
kubectl apply -f kubernetes/mongodb/mongodb-service.yaml

kubectl apply -f kubernetes/backend/backend-secret.yaml
kubectl apply -f kubernetes/backend/backend-configmap.yaml
kubectl apply -f kubernetes/backend/backend-deployment.yaml
kubectl apply -f kubernetes/backend/backend-service.yaml

kubectl apply -f kubernetes/ingress.yaml

echo "==> Waiting for deployments to be ready..."
kubectl rollout status deployment/mongodb -n muchtodo --timeout=120s
kubectl rollout status deployment/muchtodo-backend -n muchtodo --timeout=120s

echo "==> Deployment complete!"
echo "==> Pod status:"
kubectl get pods -n muchtodo
echo "==> Services:"
kubectl get services -n muchtodo
echo "==> API available at http://localhost:30080"
