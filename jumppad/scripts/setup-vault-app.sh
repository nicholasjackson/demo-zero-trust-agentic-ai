#!/bin/sh
set -e

# Database configuration constants
DB_HOST="server.demo.k8s-cluster.local.jmpd.in"
DB_PORT="30432" # DB is in k8s so use nodeport that is exposed to k8s server
DB_NAME="customers"
DB_USER="admin"
DB_PASSWORD="password"

# Function to configure database secrets engine
configure_database() {
  echo "================================"
  echo "Configuring Vault Database Secrets Engine"
  echo "================================"

  # Wait for customer database to be ready via NodePort
  echo "Waiting for customer database to be accessible..."
  MAX_RETRIES=30
  RETRY_COUNT=0
  until nc -z ${DB_HOST} ${DB_PORT} 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]; then
      echo "ERROR: Database not accessible after ${MAX_RETRIES} attempts"
      return 1
    fi
    echo "Database not ready yet (attempt ${RETRY_COUNT}/${MAX_RETRIES}), waiting..."
    sleep 2
  done
  echo "Database is accessible!"

  # Check if database secrets engine is already enabled
  echo "Checking if database secrets engine is already configured..."
  if vault secrets list | grep -q "^database/"; then
    echo "Database secrets engine already enabled at database/. Checking configuration..."

    # Check if customer-db connection exists
    if vault read database/config/customer-db > /dev/null 2>&1; then
      echo "customer-db connection already configured."

      # Verify the role exists
      if vault read database/roles/customer-readonly > /dev/null 2>&1; then
        echo "customer-readonly role already configured."
        echo "Database configuration already complete!"
        return 0
      fi
    fi
  fi

  # Enable database secrets engine if not already enabled
  if ! vault secrets list | grep -q "^database/"; then
    echo "Enabling database secrets engine..."
    vault secrets enable database
    echo "Database secrets engine enabled!"
  else
    echo "Database secrets engine already enabled."
  fi

  # Configure PostgreSQL connection
  echo "Configuring customer database connection..."
  vault write database/config/customer-db \
    plugin_name=postgresql-database-plugin \
    allowed_roles="customer-readonly,customer-readwrite" \
    connection_url="postgresql://{{username}}:{{password}}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable" \
    username="${DB_USER}" \
    password="${DB_PASSWORD}" \
    max_open_connections=5 \
    max_idle_connections=0 \
    max_connection_lifetime="1h"

  echo "Customer database connection configured!"

  # Test the connection
  echo "Testing database connection..."
  if vault read database/config/customer-db > /dev/null 2>&1; then
    echo "Database connection configuration verified!"
  else
    echo "ERROR: Failed to verify database connection configuration"
    return 1
  fi

  # Create a read-only role for customer database
  echo "Creating customer-readonly role..."
  vault write database/roles/customer-readonly \
    db_name=customer-db \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
      GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
      GRANT USAGE ON SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

  echo "customer-readonly role created!"

  # Create a read-write role for customer database
  echo "Creating customer-readwrite role..."
  vault write database/roles/customer-readwrite \
    db_name=customer-db \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
      GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\"; \
      GRANT USAGE ON SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

  echo "customer-readwrite role created!"

  # Create a policy for customer database read-only access
  echo "Creating customer-db-readonly policy..."
  vault policy write customer-db-readonly - <<EOF
# Allow reading customer database credentials
path "database/creds/customer-readonly" {
  capabilities = ["read"]
}
EOF

  echo "customer-db-readonly policy created!"

  # Create a policy for customer database read-write access
  echo "Creating customer-db-readwrite policy..."
  vault policy write customer-db-readwrite - <<EOF
# Allow reading customer database credentials with read-write access
path "database/creds/customer-readwrite" {
  capabilities = ["read"]
}
EOF

  echo "customer-db-readwrite policy created!"

  # Test credential generation
  echo "Testing credential generation..."
  echo "Generating read-only credentials..."
  READONLY_CREDS=$(vault read -format=json database/creds/customer-readonly)
  if [ $? -eq 0 ]; then
    READONLY_USERNAME=$(echo ${READONLY_CREDS} | jq -r '.data.username')
    echo "Successfully generated read-only credentials for user: ${READONLY_USERNAME}"

    # Revoke the test credentials
    READONLY_LEASE=$(echo ${READONLY_CREDS} | jq -r '.lease_id')
    vault lease revoke ${READONLY_LEASE}
    echo "Test credentials revoked."
  else
    echo "ERROR: Failed to generate read-only credentials"
    return 1
  fi

  echo "Database configuration complete!"
}

# Function to configure Kubernetes auth role
configure_k8s_auth() {
  echo ""
  echo "================================"
  echo "Configuring Kubernetes Auth Role for Customer Agent"
  echo "================================"

  # Create service account for customer-agent if it doesn't exist
  echo "Creating customer-agent service account..."
  kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: customer-agent
  namespace: customer-agent
EOF

  echo "Service account created!"

  # Create Kubernetes auth role for customer-agent
  # Note: This uses the existing kubernetes auth method configured by setup-k8s-auth.sh
  echo "Creating Kubernetes auth role: customer-agent..."
  vault write auth/demo-auth-mount/role/customer-agent \
    bound_service_account_names="customer-agent" \
    bound_service_account_namespaces="customer-agent" \
    token_ttl="1h" \
    token_policies="customer-db-readonly"

  echo "Role created: customer-agent"
  echo "  - Auth Mount: demo-auth-mount"
  echo "  - Bound Service Account: customer-agent"
  echo "  - Bound Namespace: customer-agent"
  echo "  - Policies: customer-db-readonly"
  echo "  - Token TTL: 1h"

  echo "Kubernetes auth configuration complete!"
}

# Main execution
echo "================================"
echo "Vault Application Configuration"
echo "================================"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status > /dev/null 2>&1; do
  sleep 1
done
echo "Vault is ready!"

# Configure database (may skip if already configured)
configure_database

# Always configure Kubernetes auth (idempotent)
configure_k8s_auth

echo ""
echo "================================"
echo "Vault Configuration Complete!"
echo "================================"
echo ""
echo "Database Configuration:"
echo "  - Host: ${DB_HOST}:${DB_PORT}"
echo "  - Database: ${DB_NAME}"
echo ""
echo "Database Roles:"
echo "  - customer-readonly (SELECT only, 1h TTL)"
echo "  - customer-readwrite (SELECT, INSERT, UPDATE, DELETE, 1h TTL)"
echo ""
echo "Kubernetes Auth:"
echo "  - Auth mount: demo-auth-mount/"
echo "  - Role: customer-agent"
echo "  - Service Account: customer-agent (namespace: customer-agent)"
echo "  - Policy: customer-db-readonly"
echo ""
echo "To generate database credentials:"
echo "  vault read database/creds/customer-readonly"
echo "  vault read database/creds/customer-readwrite"
echo ""
echo "To test Kubernetes auth from customer-agent pod:"
echo "  vault write auth/demo-auth-mount/login \\"
echo "    role=customer-agent \\"
echo "    jwt=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
echo ""
