#!/bin/sh
set -e

echo "======================================"
echo "Configuring Kubernetes Auth And Roles "
echo "======================================"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status > /dev/null 2>&1; do
  sleep 1
done
echo "Vault is ready!"

# Check if auth method is already enabled
echo "Checking if Kubernetes auth is already configured at kubernetes..."
SKIP_INFRA=false
if vault auth list | grep -q "^kubernetes/"; then
  echo "Auth method already enabled at kubernetes/. Skipping infrastructure setup."
  SKIP_INFRA=true
else
  echo "Auth method not found, proceeding with full configuration..."
fi

if [ "$SKIP_INFRA" = false ]; then
# Enable Kubernetes auth method
echo "Enabling Kubernetes auth method at kubernetes..."
vault auth enable -path=kubernetes kubernetes

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
vault write auth/kubernetes/config \
  kubernetes_host="${K8S_HOST}" \
  kubernetes_ca_cert="${K8S_CA_CERT}" \
  token_reviewer_jwt="${TOKEN_REVIEWER_JWT}"

echo "Kubernetes auth configured!"
fi

echo "======================================"
echo "Configuring Auth Roles and Entities"
echo "======================================"

# Create Kubernetes auth role for customer-agent
echo "Creating Kubernetes auth role: customer-agent..."
vault write auth/kubernetes/role/customer-agent \
  bound_service_account_names="customer-agent" \
  bound_service_account_namespaces="customer-agent" \
  token_ttl="1h" \
  token_policies="customer-agent-server-cert"

# Create Kubernetes auth role for customer-tool
echo "Creating Kubernetes auth role: customer-tool..."
vault write auth/kubernetes/role/customer-tool \
  bound_service_account_names="customer-tool" \
  bound_service_account_namespaces="customer-agent" \
  token_ttl="1h" \
  token_policies="customer-tool-server-cert,customer-db-readonly"

# Create Kubernetes auth role for customer-tool-db
echo "Creating Kubernetes auth role: customer-tool-db..."
vault write auth/kubernetes/role/customer-tool-db \
  bound_service_account_names="customer-tool-db" \
  bound_service_account_namespaces="customer-agent" \
  token_ttl="1h" \
  token_policies="customer-tool-db-server-cert"

# Create Kubernetes auth role for weather-agent
echo "Creating Kubernetes auth role: weather-agent..."
vault write auth/kubernetes/role/weather-agent \
  bound_service_account_names="weather-agent" \
  bound_service_account_namespaces="weather-agent" \
  token_ttl="1h" \
  token_policies="weather-tool-server-cert"

# Create Kubernetes auth role for weather-tool
echo "Creating Kubernetes auth role: weather-tool..."
vault write auth/kubernetes/role/weather-tool \
  bound_service_account_names="weather-tool" \
  bound_service_account_namespaces="weather-agent" \
  token_ttl="1h" \
  token_policies="weather-tool-server-cert"

echo "Kubernetes auth roles configured!"

# Get the Kubernetes auth accessor for entity alias creation
echo "Getting Kubernetes auth accessor..."
K8S_AUTH_ACCESSOR=$(vault auth list -format=json | jq -r '.["kubernetes/"].accessor')
echo "Kubernetes auth accessor: ${K8S_AUTH_ACCESSOR}"

# Create Vault entities with descriptive metadata
echo "Creating Vault entities with metadata..."

# Customer-agent entity
echo "Creating entity: customer-agent..."
CUSTOMER_AGENT_ENTITY=$(vault write -format=json identity/entity \
  name="customer-agent" \
  metadata=function="LangChain agent that orchestrates customer service workflows using MCP tools" \
  | jq -r '.data.id')
echo "Created customer-agent entity with ID: ${CUSTOMER_AGENT_ENTITY}"

vault write identity/entity-alias \
  name="customer-agent/customer-agent" \
  canonical_id="${CUSTOMER_AGENT_ENTITY}" \
  mount_accessor="${K8S_AUTH_ACCESSOR}"

# Customer-tool entity
echo "Creating entity: customer-tool..."
CUSTOMER_TOOL_ENTITY=$(vault write -format=json identity/entity \
  name="customer-tool" \
  metadata=function="FastMCP server providing customer information retrieval tools" \
  | jq -r '.data.id')
echo "Created customer-tool entity with ID: ${CUSTOMER_TOOL_ENTITY}"

vault write identity/entity-alias \
  name="customer-agent/customer-tool" \
  canonical_id="${CUSTOMER_TOOL_ENTITY}" \
  mount_accessor="${K8S_AUTH_ACCESSOR}"

# Customer-tool-db entity
echo "Creating entity: customer-tool-db..."
CUSTOMER_TOOL_DB_ENTITY=$(vault write -format=json identity/entity \
  name="customer-tool-db" \
  metadata=function="Database service for customer data storage and retrieval" \
  | jq -r '.data.id')
echo "Created customer-tool-db entity with ID: ${CUSTOMER_TOOL_DB_ENTITY}"

vault write identity/entity-alias \
  name="customer-agent/customer-tool-db" \
  canonical_id="${CUSTOMER_TOOL_DB_ENTITY}" \
  mount_accessor="${K8S_AUTH_ACCESSOR}"

# Weather-agent entity
echo "Creating entity: weather-agent..."
WEATHER_AGENT_ENTITY=$(vault write -format=json identity/entity \
  name="weather-agent" \
  metadata=function="LangChain agent that provides weather information using OpenWeather API via MCP tools" \
  | jq -r '.data.id')
echo "Created weather-agent entity with ID: ${WEATHER_AGENT_ENTITY}"

vault write identity/entity-alias \
  name="weather-agent/weather-agent" \
  canonical_id="${WEATHER_AGENT_ENTITY}" \
  mount_accessor="${K8S_AUTH_ACCESSOR}"

# Weather-tool entity
echo "Creating entity: weather-tool..."
WEATHER_TOOL_ENTITY=$(vault write -format=json identity/entity \
  name="weather-tool" \
  metadata=function="FastMCP server providing weather forecast tools via OpenWeather API" \
  | jq -r '.data.id')
echo "Created weather-tool entity with ID: ${WEATHER_TOOL_ENTITY}"

vault write identity/entity-alias \
  name="weather-agent/weather-tool" \
  canonical_id="${WEATHER_TOOL_ENTITY}" \
  mount_accessor="${K8S_AUTH_ACCESSOR}"

echo "Vault entities created and linked to Kubernetes auth roles!"
echo "Setup complete!"