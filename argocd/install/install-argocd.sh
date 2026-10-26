#!/usr/bin/env bash
set -euo pipefail

# Installs ArgoCD into the 'argocd' namespace on whatever cluster
# your current kubeconfig context points at (your kind cluster).

ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"

echo "==> Creating argocd namespace"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing ArgoCD (${ARGOCD_VERSION}) manifests"
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "==> Waiting for argocd-server to be ready (this can take a minute or two)"
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s

echo "==> ArgoCD installed."
echo ""
echo "Next steps:"
echo "  1. Port-forward the UI:"
echo "       kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "  2. Get the initial admin password:"
echo "       kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo "  3. Open https://localhost:8080 and log in as 'admin' with that password."
echo "  4. Push this repo to your own Git remote, then edit the repoURL in"
echo "     argocd/applications/nginx-demo-*.yaml to point at it."
echo "  5. Apply the Applications:"
echo "       kubectl apply -f argocd/applications/nginx-demo-dev.yaml"
echo "       kubectl apply -f argocd/applications/nginx-demo-prod.yaml"
