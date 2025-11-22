# Vault Token Exchange Plugin Demo
# This Jumppad configuration sets up a complete demo environment with:
# - Keycloak as OIDC provider
# - HashiCorp Vault with the token exchange plugin
# - Network isolation for secure communication

# Variables for configuration
variable "plugin_version" {
  default     = "v0.0.5"
  description = "Version of the vault-plugin-identity-delegation to download from GitHub releases"
}

variable "plugin_platform" {
  default     = "linux-amd64"
  description = "Platform binary to download (linux-amd64, darwin-amd64, darwin-arm64, etc.)"
}

variable "run_scripts" {
  default     = true
  description = "Run the setup scripts for vault and keycloak"
}

variable "install_app" {
  default     = true
  description = "Install the application to kubernetes"
}

variable "enable_keycloak" {
  default = false
}

# Create an isolated network for the demo
resource "network" "demo" {
  subnet = "10.16.0.0/16"
}

output "PLUGIN_VERSION" {
  value = variable.plugin_version
}

output "PLUGIN_PLATFORM" {
  value = variable.plugin_platform
}

output "KEYCLOAK_URL" {
  value = "http://localhost:8080"
}

output "KEYCLOAK_ADMIN" {
  value = "admin"
}

output "KEYCLOAK_ADMIN_PASSWORD" {
  value = "admin"
}

output "VAULT_ADDR" {
  value = "http://localhost:8200"
}

output "VAULT_TOKEN" {
  value = "root"
}