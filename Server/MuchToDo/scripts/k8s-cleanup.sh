#!/bin/bash
set -e

echo "==> Cleaning up Kubernetes resources..."

kubectl delete -f kubernetes/ingress.yaml --ignore-not-found
kubectl delete -f kubernetes/backend/ --ignore-not-found
kubectl delete -f kubernetes/mongodb/ --ignore-not-found
kubectl delete -f kubernetes/namespace.yaml --ignore-not-found

echo "==> Deleting Kind cluster..."
kind delete cluster --name muchtodo-cluster

echo "==> Cleanup complete!"
