#!/bin/sh
set -e

echo "================================"
echo "Configuring Vault Token Exchange Plugin"
echo "================================"

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status > /dev/null 2>&1; do
  sleep 1
done
echo "Vault is ready!"

CURRENT_DIR=$(dirname "$0")
PLUGIN_DIR="${CURRENT_DIR}/../build"

# Check if plugin is already enabled
echo "Checking if identity-delegation plugin is already configured..."
if vault secrets list | grep -q "^identity-delegation/"; then
  echo "Plugin already enabled at identity-delegation/. Skipping configuration."
  exit 0
fi
echo "Plugin not found, proceeding with configuration..."

# Get the plugin SHA256
echo "Calculating plugin SHA256..."
PLUGIN_SHA256=$(sha256sum ${PLUGIN_DIR}/vault-plugin-identity-delegation | cut -d' ' -f1)
echo "Plugin SHA256: ${PLUGIN_SHA256}"

# Register the plugin
echo "Registering token exchange plugin..."
vault plugin register \
  -sha256="${PLUGIN_SHA256}" \
  -command="vault-plugin-identity-delegation" \
  secret \
  vault-plugin-identity-delegation

echo "Plugin registered successfully!"

# Enable the plugin
echo "Enabling token exchange plugin at path: identity-delegation"
vault secrets enable \
  -path=identity-delegation \
  -plugin-name=vault-plugin-identity-delegation \
  plugin

echo "Plugin enabled successfully!"

# Configure the plugin with Keycloak JWKS endpoint
echo "Configuring plugin with Keycloak JWKS endpoint..."

# Wait for Keycloak to be ready (it might still be starting up)
echo "Waiting for Keycloak to be ready..."
until curl -sf "${KEYCLOAK_URL}/realms/master/.well-known/openid-configuration" > /dev/null 2>&1; do
  echo "Keycloak not ready yet, waiting..."
  sleep 2
done
echo "Keycloak is ready!"

# Generate a signing key for token generation
echo "Generating RSA signing key..."
SIGNING_KEY=$(cat <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAu1SU1LfVLPHCozMxH2Mo4lgOEePzNm0tRgeLezV6ffAt0gun
VTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u+qKhbwKfBstIs+bMY2Zkp18gnTxK
LxoS2tFczGkPLPgizskuemMghRniWaoLcyehkd3qqGElvW/VDL5AaWTg0nLVkjRo
9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ0iT9wCS0DRTXu269V264Vf/3jvre
dZW2xOQ4YJO2rnFmHiHHHZhpZuOFMfDQ2vLNZ0P6vNhJJmyM1f4pEhzT9LFBnXWj
z/4SfmQC4Gy2z1VSXO5wbT8eFPaD3JtO0zSXPwIDAQABAoIBAQCdD8bCR1kRQx9x
sdLrNNpCIvKWGH8pAJ3H+KXzR4kBlRSvFH1c7/8K8TLvYrATvO9mJeD2nLgU8M9f
vBAcW8fK/UkJXZPcXuJqGhJLu1DUZiU2xvH5LL3e8DPHmvz6LFjmFbCPQSLTKqLU
F0v3jYmAOZbNqHRhLEFg0KFzxfQxK7vVWqBD3OC/fJ3P6W0hxUMNvQrX3+c8fQKV
vCf2sJ8NJEqw5WNCE8qgKhjJZF1VO4YWnvfWa2bEDZKYGKmMsGGjKm5a7v6h4sVK
9o7pJmqOyqmBhREbJxLH3bYqF8M0d0HqvJWK3xLg5xW5fGNVqNwpJvjp3DMYQ5Ps
O6JfLGSxAoGBAOZzSPHHCEPkdDTKTdTM9dKNGKUQM0E1wKFGLaQwJQkzTm3S8lLB
3gKCvAjNzJ3+nS4HDw2cmqVP1QlKX6DL5mGsLmjN3b7RJWPnPKzCpOm7LwKVJvMJ
7XvKJ4qLl0eWM3H6iP3vJT2P3JEqiH0kE0R8xL5tKHZAkDj3QaP3+JOJAoGBAM+E
hQlGzKK9mKEKhJQHPjLqzPzJY6HfasDK3NrCQrZxGgQx8xJEzDVjLLpvIFBzLvX7
xmCUK1R3LvR3vwWXqMiZqKKTkKnFVmBqvVTjYmUdFTxHPFiIwFjL8lQDKmRfJ0iU
qYGE5WnGZ0VVL9PZJW0FzR0CnLSGLiEHVsE8YJ3/AoGAE+0PSMnqK7MELbLJ0RQc
vPHvKXFVLPQQJGN0VjTl5r/bDKLHZRPWFDTQKdH0kJoqGYE7FbQNGPLpjCvL9HGt
ThQ9J1qX5T5nQZ0EoQiJLqQCGGNQnLQ7MFm3xKbFO3lsLuLLNWMKPmMGLYL3GBMz
vmfJQYLBNrJmKv/7JVHJfFECgYAh7g7h2VTGJQNfvHQ8G3LPX0KxLLHLTQWLLBQB
qKqX6EKFKrqLLPQL0MqNQm0sLLz7qZJ3vWQKLPKmIqLDkKP8LQGtLFXNqQKGLLXV
mJLHLTKGLKGHQqLLKPLKGHLKHLHKPKLGLKPKGLKPKGLPKLGKPLGKLGLKPqLmBwKB
gQCBhQm6LHVnLQKPKGLGKLPKGLKGHLKPLGKPLGKLPKGLPKGLKGLPKLGKPLGKLPKG
LKPKGLKPKGLPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKG
LKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGLKPKGw==
-----END RSA PRIVATE KEY-----
EOF
)

# Configure the token exchange with Keycloak JWKS endpoint
# Note: Using demo realm for token validation
vault write identity-delegation/config \
  subject_jwks_uri="${KEYCLOAK_URL}/realms/demo/protocol/openid-connect/certs" \
  issuer="https://vault.local" \
  default_ttl="1h" \
  signing_key="${SIGNING_KEY}"

echo "Plugin configured with Keycloak JWKS endpoint!"

# Create a sample role for token exchange
echo "Creating sample token exchange role..."
vault write identity-delegation/role/demo-agent \
  bound_issuer="${KEYCLOAK_URL}/realms/demo" \
  bound_audiences="demo-app" \
  context="read:documents,write:documents" \
  ttl="1h" \
  actor_template='{"act": {"sub": "service-account-ai-agent"}}' \
  subject_template='{"email": "{{identity.subject.email}}", "name": "{{identity.subject.name}}"}'

echo "Sample role created: demo-agent"

# Create an additional role for user tokens
vault write identity-delegation/role/user-agent \
  bound_issuer="${KEYCLOAK_URL}/realms/demo" \
  bound_audiences="demo-app" \
  context="read:profile,write:profile" \
  ttl="1h" \
  actor_template='{"act": {"sub": "service-account-user-agent"}}' \
  subject_template='{"email": "{{identity.subject.email}}"}'

echo "Additional role created: user-agent"

echo ""
echo "================================"
echo "Vault Configuration Complete!"
echo "================================"
echo "Vault Address: ${VAULT_ADDR}"
echo "Vault Token: ${VAULT_TOKEN}"
echo ""
echo "Plugin enabled at: ${VAULT_ADDR}/v1/identity-delegation"
echo "Available roles:"
echo "  - demo-agent (read:documents, write:documents)"
echo "  - user-agent (read:profile, write:profile)"
echo ""
echo "To test the plugin:"
echo "  vault read identity-delegation/config"
echo "  vault list identity-delegation/role"
echo ""
