#!/bin/bash
set -e

# Check if plugin already exists
if [ -f ./build/vault-plugin-identity-delegation ]; then
  echo "Plugin binary already exists at ./build/vault-plugin-identity-delegation"
  echo "Skipping download. Delete the file to re-download."
  exit 0
fi

CURRENT_DIR=$(dirname "$0")
PLUGIN_DIR="${CURRENT_DIR}/../build"


echo "Downloading vault-plugin-identity-delegation ${PLUGIN_VERSION} for ${PLUGIN_PLATFORM}..."

# Create build directory if it doesn't exist
mkdir -p ${PLUGIN_DIR}

# Download the plugin binary from GitHub releases
RELEASE_URL="https://github.com/nicholasjackson/vault-plugin-identity-delegation/releases/download/${PLUGIN_VERSION}/vault-plugin-identity-delegation-${PLUGIN_PLATFORM}"

echo "Downloading from: $RELEASE_URL"


# Download the binary directly (not tar.gz)
curl -sfL "$RELEASE_URL" -o ${PLUGIN_DIR}/vault-plugin-identity-delegation

if [ $? -ne 0 ]; then
  echo "Error: Failed to download plugin from $RELEASE_URL"
  echo "Make sure the release exists and the platform is correct."
  echo "To build locally instead, see the commented section in main.hcl"
  exit 1
fi

# Make executable
chmod +x ${PLUGIN_DIR}/vault-plugin-token-exchange

echo "Plugin downloaded successfully!"
ls -lh ${PLUGIN_DIR}/vault-plugin-identity-delegation