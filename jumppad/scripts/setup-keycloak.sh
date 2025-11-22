#!/bin/sh
set -e

echo "================================"
echo "Configuring Keycloak OIDC Provider"
echo "================================"

# Wait for Keycloak to be fully ready
echo "Waiting for Keycloak to be ready..."
until curl -sf "${KEYCLOAK_URL}" > /dev/null 2>&1; do
  echo "Keycloak not ready yet, waiting..."
  sleep 2
done
echo "Keycloak is ready!"

# Get admin token
echo "Obtaining admin access token..."
ADMIN_TOKEN=$(curl -sf -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${KEYCLOAK_ADMIN}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "Failed to obtain admin token"
  exit 1
fi
echo "Admin token obtained!"

# Create demo realm
echo "Creating demo realm..."
curl -sf -X POST "${KEYCLOAK_URL}/admin/realms" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "demo",
    "enabled": true,
    "displayName": "Token Exchange Demo Realm"
  }' || echo "Realm might already exist"

echo "Demo realm created or already exists!"

# Create demo-app client (for end users)
echo "Creating demo-app client..."
curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/demo/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "demo-app",
    "enabled": true,
    "publicClient": false,
    "directAccessGrantsEnabled": true,
    "serviceAccountsEnabled": false,
    "standardFlowEnabled": true,
    "implicitFlowEnabled": false,
    "protocol": "openid-connect",
    "attributes": {
      "access.token.lifespan": "3600"
    },
    "redirectUris": ["http://localhost:*"],
    "webOrigins": ["http://localhost:*"]
  }' || echo "Client might already exist"

echo "demo-app client created!"

# Create ai-agent client (for AI agents)
echo "Creating ai-agent client..."
curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/demo/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "ai-agent",
    "enabled": true,
    "publicClient": false,
    "directAccessGrantsEnabled": true,
    "serviceAccountsEnabled": true,
    "standardFlowEnabled": false,
    "protocol": "openid-connect",
    "attributes": {
      "access.token.lifespan": "3600"
    }
  }' || echo "Client might already exist"

echo "ai-agent client created!"

# Get the ai-agent client secret
echo "Retrieving ai-agent client secret..."
sleep 2  # Give Keycloak a moment to fully create the client

# Get the client UUID
CLIENT_UUID=$(curl -sf "${KEYCLOAK_URL}/admin/realms/demo/clients?clientId=ai-agent" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" = "null" ]; then
  echo "Failed to retrieve ai-agent client UUID"
else
  # Get the client secret
  CLIENT_SECRET=$(curl -sf "${KEYCLOAK_URL}/admin/realms/demo/clients/${CLIENT_UUID}/client-secret" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')

  echo "ai-agent client secret: ${CLIENT_SECRET}"
fi

# Create demo users
echo "Creating demo users..."

# Create user: john@example.com
curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/demo/users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john",
    "email": "john@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "enabled": true,
    "emailVerified": true,
    "credentials": [{
      "type": "password",
      "value": "password",
      "temporary": false
    }]
  }' || echo "User john might already exist"

# Create user: jane@example.com
curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/demo/users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "jane",
    "email": "jane@example.com",
    "firstName": "Jane",
    "lastName": "Smith",
    "enabled": true,
    "emailVerified": true,
    "credentials": [{
      "type": "password",
      "value": "password",
      "temporary": false
    }]
  }' || echo "User jane might already exist"

echo "Demo users created!"

echo ""
echo "================================"
echo "Keycloak Configuration Complete!"
echo "================================"
echo "Keycloak URL: ${KEYCLOAK_URL}"
echo "Admin Console: ${KEYCLOAK_URL}/admin"
echo "Admin Credentials: ${KEYCLOAK_ADMIN} / ${KEYCLOAK_ADMIN_PASSWORD}"
echo ""
echo "Demo Realm: demo"
echo "Clients:"
echo "  - demo-app (public client for users)"
echo "  - ai-agent (confidential client for AI agents)"
echo ""
if [ -n "$CLIENT_SECRET" ] && [ "$CLIENT_SECRET" != "null" ]; then
  echo "AI Agent Client Secret: ${CLIENT_SECRET}"
  echo ""
fi
echo "Demo Users:"
echo "  - john@example.com / password"
echo "  - jane@example.com / password"
echo ""
echo "JWKS Endpoint: ${KEYCLOAK_URL}/realms/demo/protocol/openid-connect/certs"
echo "Token Endpoint: ${KEYCLOAK_URL}/realms/demo/protocol/openid-connect/token"
echo ""
