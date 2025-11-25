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