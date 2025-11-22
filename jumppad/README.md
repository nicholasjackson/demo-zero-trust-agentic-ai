# Vault Token Exchange Plugin Demo

This demo provides a complete environment to test the Vault Token Exchange plugin using Jumppad. The demo includes:

- **HashiCorp Vault** with the token exchange plugin pre-configured
- **Keycloak** as an OIDC identity provider
- Pre-configured demo realm, clients, and users
- Sample roles for token exchange scenarios

## Prerequisites

- [Jumppad](https://jumppad.dev/) installed
- Docker or Podman for container runtime
- Internet connection (to download plugin from GitHub releases)

## Plugin Source

By default, the demo downloads the plugin binary from GitHub releases:
- Repository: https://github.com/nicholasjackson/vault-plugin-identity-delegation/releases
- Default version: `v0.0.5` (latest)
- Default platform: `linux-amd64`

Available platforms:
- `linux-amd64` (default for containers)
- `linux-arm64`
- `darwin-amd64`
- `darwin-arm64`
- `windows-amd64` (with .exe extension)

### Using a Different Version

To use a different release version or platform:

```bash
cd demo
jumppad up --var plugin_version=v0.0.5 --var plugin_platform=darwin-arm64
```

### Building Locally (Alternative)

If GitHub releases are not available or you want to build from source:

1. Edit `main.hcl` and comment out the `download_plugin` resource
2. Uncomment the `local_build_plugin` resource section
3. Update the Vault container's `depends_on` as noted in the comments
4. Run `jumppad up`

## Quick Start

### Automatic Setup (Recommended)

1. Start the demo environment with automatic configuration:
   ```bash
   cd demo
   jumppad up
   ```

2. Wait for all services to start and configure (this may take 1-2 minutes)
   - The plugin will be downloaded from GitHub releases automatically
   - Keycloak and Vault will start
   - Setup scripts will run automatically to configure both services

3. Access the services:
   - Vault UI: http://localhost:8200/ui (token: `root`)
   - Keycloak Admin: http://localhost:8080/admin (admin / admin)

### Manual Setup (Optional)

If you prefer to configure manually or skip auto-configuration:

1. Start containers only (without running setup scripts):
   ```bash
   cd demo
   # Comment out the configure_vault and configure_keycloak resources in main.hcl
   jumppad up
   ```

2. Manually run setup scripts when ready:
   ```bash
   # Configure Keycloak
   ./scripts/setup-keycloak.sh

   # Configure Vault
   ./scripts/setup-vault.sh
   ```

## What Gets Configured

### Keycloak Setup

The demo creates a Keycloak realm called `demo` with:

**Clients:**
- `demo-app` - Public client for end-user authentication
- `ai-agent` - Confidential client (for demonstration, not used in token exchange)

**Users:**
- `john@example.com` / `password`
- `jane@example.com` / `password`

**Endpoints:**
- Token endpoint: `http://localhost:8080/realms/demo/protocol/openid-connect/token`
- JWKS endpoint: `http://localhost:8080/realms/demo/protocol/openid-connect/certs`

### Vault Setup

The demo configures Vault with:

**Plugin Configuration:**
- Registered and enabled at path: `token-exchange`
- Connected to Keycloak JWKS endpoint for token validation

**Roles:**
- `demo-agent` - For document access (scopes: read:documents, write:documents)
- `user-agent` - For profile access (scopes: read:profile, write:profile)

**Actor Identity:**
- The plugin uses Vault's built-in entity system for actor identity
- Actor identity is derived from the Vault token used to call the plugin
- No separate actor_token parameter is required

## Testing the Token Exchange

### Step 1: Get a User Token from Keycloak

```bash
# Get a token for user John
USER_TOKEN=$(curl -s -X POST "http://localhost:8080/realms/demo/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=john@example.com" \
  -d "password=password" \
  -d "grant_type=password" \
  -d "client_id=demo-app" | jq -r '.access_token')

echo "User Token: $USER_TOKEN"

# Decode the token to see its contents
echo $USER_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .
```

### Step 2: Exchange Token via Vault

```bash
# Exchange the user token using the demo-agent role
# Note: Vault uses its own entity system for actor identity (no explicit actor_token needed)
EXCHANGED_TOKEN=$(curl -s -X POST "http://localhost:8200/v1/token-exchange/token/demo-agent" \
  -H "X-Vault-Token: root" \
  -H "Content-Type: application/json" \
  -d "{
    \"subject_token\": \"$USER_TOKEN\"
  }" | jq -r '.data.token')

echo "Exchanged Token: $EXCHANGED_TOKEN"

# Decode the exchanged token to see the RFC 8693 compliant structure
echo $EXCHANGED_TOKEN | cut -d'.' -f2 | base64 -d 2>/dev/null | jq .
```

### Expected Token Structure (RFC 8693 Compliant)

The exchanged token should contain:

```json
{
  "iss": "https://vault.local",
  "sub": "john@example.com",
  "aud": "demo-app",
  "exp": 1234567890,
  "iat": 1234564290,
  "act": {
    "sub": "service-account-ai-agent"
  },
  "scope": "read:documents write:documents",
  "subject_claims": {
    "email": "john@example.com",
    "name": "John Doe",
    ...
  }
}
```

Key features:
- **`sub`**: The end user (John)
- **`act.sub`**: The AI agent acting on behalf of the user
- **`scope`**: The delegated permissions
- **`subject_claims`**: Original user token claims

## Verifying RFC 8693 Compliance

The exchanged token follows RFC 8693 (OAuth 2.0 Token Exchange) specification:

1. Uses standard `act` claim for actor identity (not custom `obo`)
2. `sub` contains the user identity
3. `act.sub` contains the agent/actor identity
4. Scopes are in space-delimited format in `scope` claim
5. Clear audit trail of delegation

## Cleanup

To stop and remove all containers:

```bash
jumppad down
```

## Troubleshooting

### Services not starting

If services fail to start, check the logs:

```bash
# Check Vault logs
jumppad logs vault

# Check Keycloak logs
jumppad logs keycloak
```

### Plugin not registered

If the plugin fails to register, check if the binary downloaded successfully:

```bash
ls -lh demo/build/vault-plugin-token-exchange
```

The plugin binary should be present and executable.

If the download failed:
1. Check that the specified version exists in GitHub releases
2. Verify internet connectivity
3. Consider building locally instead (see "Building Locally" section above)

### Keycloak not accessible

Ensure Keycloak has fully started (can take 30-60 seconds):

```bash
curl http://localhost:8080/health/ready
```

## Architecture

```
┌─────────────────┐
│   Keycloak      │  OIDC Provider
│   :8080         │  - Realm: demo
└────────┬────────┘  - Users & Clients
         │
         │ JWKS validation
         │
         ▼
┌─────────────────┐
│   Vault         │  Token Exchange
│   :8200         │  - Plugin enabled
└─────────────────┘  - Roles configured
```

## Next Steps

- Customize roles with different scopes
- Add more users and test different scenarios
- Integrate with resource servers that validate the exchanged tokens
- Explore delegation chains (multi-hop token exchange)

## References

- [RFC 8693: OAuth 2.0 Token Exchange](https://www.rfc-editor.org/rfc/rfc8693.html)
- [Plugin Documentation](../CLAUDE.md)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Vault Plugin Documentation](https://developer.hashicorp.com/vault/docs/plugins)
