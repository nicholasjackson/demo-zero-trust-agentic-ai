vault policy write weather-agent-policy - <<EOF
path "identity-delegation/token/weather-agent" {
  capabilities = ["create","update"]
}
EOF

# Configure the plugin to validate keycloak
vault write identity-delegation/config \
    issuer="https://vault.example.com" \
    subject_jwks_uri="http://127.0.0.1:8200/v1/identity/oidc/.well-known/keys" \
    default_ttl="1h" > /dev/null

vault write identity-delegation/key/weather-agent \
    algorithm="RS256" > /dev/null

vault write identity-delegation/role/weather-agent \
    key="weather-agent" \
    ttl="1h" \
    context="urn:weather.tools:read" \
    actor_template='{"username": "{{identity.entity.id}}" }' \
    subject_template='{"username": "{{identity.subject.username}}" }' > /dev/null