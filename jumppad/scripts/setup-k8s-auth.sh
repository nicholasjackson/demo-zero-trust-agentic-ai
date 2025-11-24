#!/bin/sh
set -e

echo "================================"
echo "Configuring Vault Kubernetes Auth for VSO"
echo "================================"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status > /dev/null 2>&1; do
  sleep 1
done
echo "Vault is ready!"

# Check if auth method is already enabled
echo "Checking if Kubernetes auth is already configured at demo-auth-mount..."
if vault auth list | grep -q "^demo-auth-mount/"; then
  echo "Auth method already enabled at demo-auth-mount/. Skipping configuration."
  exit 0
fi
echo "Auth method not found, proceeding with configuration..."

# Enable Kubernetes auth method
echo "Enabling Kubernetes auth method at demo-auth-mount..."
vault auth enable -path=demo-auth-mount kubernetes

echo "Kubernetes auth enabled!"

# Create service account for Vault to use for TokenReview
echo "Creating Vault service account with TokenReview permissions..."

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-auth
  namespace: default
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-token
  namespace: default
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: default
EOF

echo "Waiting for token to be created..."
sleep 2

# Get the Kubernetes configuration from the cluster
echo "Retrieving Kubernetes configuration..."

# Get the Kubernetes API host from the kubeconfig
K8S_HOST=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
echo "Kubernetes API host: ${K8S_HOST}"

# Get the CA cert for API server verification
echo "Getting Kubernetes cluster CA certificate..."
K8S_CA_CERT=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)

# Get the service account JWT token for Vault to use
echo "Getting Vault service account token..."
TOKEN_REVIEWER_JWT=$(kubectl get secret vault-auth-token -n default -o jsonpath='{.data.token}' | base64 -d)

# Configure Kubernetes auth
# The Kubernetes auth method uses the TokenReview API to validate service account tokens
echo "Configuring Vault Kubernetes auth..."
vault write auth/demo-auth-mount/config \
  kubernetes_host="${K8S_HOST}" \
  kubernetes_ca_cert="${K8S_CA_CERT}" \
  token_reviewer_jwt="${TOKEN_REVIEWER_JWT}"

echo "Kubernetes auth configured!"