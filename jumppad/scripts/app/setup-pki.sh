#!/bin/sh
set -e

echo "================================"
echo "Configuring Vault PKI for PostgreSQL TLS"
echo "================================"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status > /dev/null 2>&1; do
  sleep 1
done
echo "Vault is ready!"

# Check if PKI is already enabled
if vault secrets list | grep -q "^pki/"; then
  echo "PKI already enabled, skipping setup..."
  exit 0
fi

# ===== ROOT CA SETUP =====
echo ""
echo "Setting up Root CA..."

# Enable root PKI
vault secrets enable -path=pki pki
vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA
vault write -field=certificate pki/root/generate/internal \
    common_name="Demo Root CA" \
    issuer_name="root-2025" \
    ttl=87600h > /tmp/root_ca.crt

echo "Root CA certificate saved to /tmp/root_ca.crt"

# Configure CA and CRL URLs
vault write pki/config/urls \
    issuing_certificates="http://vault.default.svc.cluster.local:8200/v1/pki/ca" \
    crl_distribution_points="http://vault.default.svc.cluster.local:8200/v1/pki/crl"

echo "Root CA configured!"

# ===== CREATE ROLES =====
echo ""
echo "Creating certificate roles..."

# Customer Tool Database server certificate role
vault write pki/roles/customer-tool-db-server \
    allowed_domains="customer-tool-db.customer-agent.svc.cluster.local" \
    allow_bare_domains=true \
    allow_subdomains=false \
    allow_localhost=true \
    allow_ip_sans=true \
    max_ttl="8760h" \
    key_type="rsa" \
    key_bits="2048" \
    server_flag=true \
    client_flag=false

echo "customer-tool-db-server role created!"

# Customer Tool server certificate role
vault write pki/roles/customer-tool-server \
    allowed_domains="customer-tool.customer-agent.svc.cluster.local" \
    allow_bare_domains=true \
    allow_subdomains=false \
    allow_localhost=true \
    max_ttl="8760h" \
    key_type="rsa" \
    key_bits="2048" \
    server_flag=true \
    client_flag=false

echo "customer-tool-server role created!"

# Customer Agent server certificate role
vault write pki/roles/customer-agent-server \
    allowed_domains="customer-agent.customer-agent.svc.cluster.local" \
    allow_bare_domains=true \
    allow_subdomains=false \
    allow_localhost=true \
    max_ttl="8760h" \
    key_type="rsa" \
    key_bits="2048" \
    server_flag=true \
    client_flag=false

echo "customer-agent-server role created!"

# ===== CREATE POLICIES =====
echo ""
echo "Creating PKI policies..."

# Customer Tool Database server certificate policy
vault policy write customer-tool-db-server-cert - <<EOF
# Allow issuing customer-tool-db server certificates
path "pki/issue/customer-tool-db-server" {
  capabilities = ["create", "update"]
}

# Read CA certificate
path "pki/cert/ca" {
  capabilities = ["read"]
}

# List certificates
path "pki/certs" {
  capabilities = ["list"]
}
EOF

echo "customer-tool-db-server-cert policy created!"

# Customer Tool server certificate policy
vault policy write customer-tool-server-cert - <<EOF
# Allow issuing customer-tool server certificates
path "pki/issue/customer-tool-server" {
  capabilities = ["create", "update"]
}

# Read CA certificate
path "pki/cert/ca" {
  capabilities = ["read"]
}

# List certificates
path "pki/certs" {
  capabilities = ["list"]
}
EOF

echo "customer-tool-server-cert policy created!"

# Customer Agent server certificate policy
vault policy write customer-agent-server-cert - <<EOF
# Allow issuing customer-agent server certificates
path "pki/issue/customer-agent-server" {
  capabilities = ["create", "update"]
}

# Read CA certificate
path "pki/cert/ca" {
  capabilities = ["read"]
}

# List certificates
path "pki/certs" {
  capabilities = ["list"]
}
EOF

echo "customer-agent-server-cert policy created!"

# ===== TEST CERTIFICATE GENERATION =====
echo ""
echo "Testing certificate generation..."

# Test customer-tool-db server certificate
echo "Generating test customer-tool-db server certificate..."
vault write -format=json pki/issue/customer-tool-db-server \
    common_name=customer-tool-db.customer-agent.svc.cluster.local \
    ip_sans="127.0.0.1" \
    ttl=24h > /tmp/test_db_cert.json

if [ $? -eq 0 ]; then
    echo "customer-tool-db certificate generated successfully!"
    echo "  Serial: $(jq -r '.data.serial_number' /tmp/test_db_cert.json)"
    DB_SERIAL=$(jq -r '.data.serial_number' /tmp/test_db_cert.json)
else
    echo "ERROR: Failed to generate customer-tool-db certificate"
    exit 1
fi

# Test customer-tool server certificate
echo "Generating test customer-tool server certificate..."
vault write -format=json pki/issue/customer-tool-server \
    common_name=customer-tool.customer-agent.svc.cluster.local \
    ttl=24h > /tmp/test_tool_cert.json

if [ $? -eq 0 ]; then
    echo "customer-tool certificate generated successfully!"
    echo "  Serial: $(jq -r '.data.serial_number' /tmp/test_tool_cert.json)"
    TOOL_SERIAL=$(jq -r '.data.serial_number' /tmp/test_tool_cert.json)
else
    echo "ERROR: Failed to generate customer-tool certificate"
    exit 1
fi

# Test customer-agent server certificate
echo "Generating test customer-agent server certificate..."
vault write -format=json pki/issue/customer-agent-server \
    common_name=customer-agent.customer-agent.svc.cluster.local \
    ttl=24h > /tmp/test_agent_cert.json

if [ $? -eq 0 ]; then
    echo "customer-agent certificate generated successfully!"
    echo "  Serial: $(jq -r '.data.serial_number' /tmp/test_agent_cert.json)"
    AGENT_SERIAL=$(jq -r '.data.serial_number' /tmp/test_agent_cert.json)

    # Revoke test certificates
    echo "Revoking test certificates..."
    vault write pki/revoke serial_number="${DB_SERIAL}"
    vault write pki/revoke serial_number="${TOOL_SERIAL}"
    vault write pki/revoke serial_number="${AGENT_SERIAL}"
    echo "Test certificates revoked."
else
    echo "ERROR: Failed to generate customer-agent certificate"
    exit 1
fi

# ===== SUMMARY =====
echo ""
echo "================================"
echo "PKI Configuration Complete!"
echo "================================"
echo ""
echo "Root CA:"
echo "  - Path: pki/"
echo "  - Max TTL: 87600h (10 years)"
echo ""
echo "Roles (specific server certificates only):"
echo "  - customer-tool-db-server: Server certificates for customer-tool-db"
echo "    - Allowed domain: customer-tool-db.customer-agent.svc.cluster.local"
echo "  - customer-tool-server: Server certificates for customer-tool"
echo "    - Allowed domain: customer-tool.customer-agent.svc.cluster.local"
echo "  - customer-agent-server: Server certificates for customer-agent"
echo "    - Allowed domain: customer-agent.customer-agent.svc.cluster.local"
echo ""
echo "Policies:"
echo "  - customer-tool-db-server-cert: Issue customer-tool-db server certificates"
echo "  - customer-tool-server-cert: Issue customer-tool server certificates"
echo "  - customer-agent-server-cert: Issue customer-agent server certificates"
echo ""
echo "To generate certificates:"
echo "  vault write pki/issue/customer-tool-db-server \\"
echo "    common_name=customer-tool-db.customer-agent.svc.cluster.local \\"
echo "    ip_sans=127.0.0.1 \\"
echo "    ttl=8760h"
echo ""
echo "  vault write pki/issue/customer-tool-server \\"
echo "    common_name=customer-tool.customer-agent.svc.cluster.local \\"
echo "    ttl=8760h"
echo ""
echo "  vault write pki/issue/customer-agent-server \\"
echo "    common_name=customer-agent.customer-agent.svc.cluster.local \\"
echo "    ttl=8760h"
echo ""
