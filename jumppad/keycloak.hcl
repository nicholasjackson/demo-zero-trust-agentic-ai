# Keycloak OIDC Provider
resource "container" "keycloak" {
  disabled = !variable.enable_keycloak

  network {
    id         = resource.network.demo.meta.id
    ip_address = "10.16.0.10"
    aliases    = ["keycloak"]
  }

  image {
    name = "quay.io/keycloak/keycloak:26.0"
  }

  command = [
    "start-dev"
  ]

  environment = {
    KC_BOOTSTRAP_ADMIN_USERNAME = "admin"
    KC_BOOTSTRAP_ADMIN_PASSWORD = "admin"
    KC_HEALTH_ENABLED           = true
  }

  port {
    local = 8080
    host  = 8080
  }

  health_check {
    timeout = "30s"
    http {
      address       = "http://localhost:8080/admin/master/console/"
      success_codes = [200]
    }
  }
}

# Configure Keycloak realm and clients
# This runs locally and can be skipped if you want to configure manually
resource "exec" "configure_keycloak" {
  disabled = !variable.run_scripts || !variable.enable_keycloak

  depends_on = ["resource.container.keycloak"]

  script = file("./scripts/setup-keycloak.sh")

  environment = {
    KEYCLOAK_URL            = "http://localhost:8080"
    KEYCLOAK_ADMIN          = "admin"
    KEYCLOAK_ADMIN_PASSWORD = "admin"
  }
}