#!/bin/sh
set -e

echo "================================"
echo "Configuring Kubernetes Auth Role for Customer Agent"
echo "================================"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status > /dev/null 2>&1; do
  sleep 1
done
echo "Vault is ready!"

# Create Kubernetes auth role for customer-agent
# Note: This uses the existing kubernetes auth method configured by setup-k8s-auth.sh
# This role binds the customer-agent service account to both database and PKI policies
echo "Creating Kubernetes auth role: customer-agent..."
vault write auth/demo-auth-mount/role/customer-agent \
  bound_service_account_names="customer-agent" \
  bound_service_account_namespaces="customer-agent" \
  token_ttl="1h" \
  token_policies="customer-db-readonly,customer-tool-db-server-cert"

echo ""
echo "================================"
echo "Kubernetes Auth Configuration Complete!"
echo "================================"
echo ""
echo "Role: customer-agent"
echo "  - Auth Mount: demo-auth-mount"
echo "  - Bound Service Account: customer-agent"
echo "  - Bound Namespace: customer-agent"
echo "  - Policies:"
echo "    - customer-db-readonly (database credentials)"
echo "    - postgres-client-cert (client certificates)"
echo "  - Token TTL: 1h"
echo ""
echo "To test Kubernetes auth from customer-agent pod:"
echo "  vault write auth/demo-auth-mount/login \\"
echo "    role=customer-agent \\"
echo "    jwt=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
echo ""
