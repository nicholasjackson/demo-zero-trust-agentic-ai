#!/bin/sh
set -e

# Database configuration constants
DB_HOST="server.demo.k8s-cluster.local.jmpd.in"
DB_PORT="30432" # DB is in k8s so use nodeport that is exposed to k8s server
DB_NAME="customers"
DB_USER="admin"
DB_PASSWORD="password"

echo "================================"
echo "Configuring Vault Database Secrets Engine"
echo "================================"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status > /dev/null 2>&1; do
  sleep 1
done
echo "Vault is ready!"

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
      exit 0
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
  connection_url="postgresql://{{username}}:{{password}}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=prefer" \
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
  exit 1
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
  exit 1
fi

echo ""
echo "================================"
echo "Database Configuration Complete!"
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
echo "Database Policies:"
echo "  - customer-db-readonly"
echo "  - customer-db-readwrite"
echo ""
echo "To generate database credentials:"
echo "  vault read database/creds/customer-readonly"
echo "  vault read database/creds/customer-readwrite"
echo ""
