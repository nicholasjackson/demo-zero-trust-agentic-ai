resource "k8s_config" "base_setup" {
  disabled   = !variable.install_app
  depends_on = ["resource.helm.vault_operator"]

  cluster = resource.k8s_cluster.demo

  paths = [
    "./k8s/base/namespace.yaml",
  ]

  wait_until_ready = true
}

resource "template" "weather_tool_secret" {
  disabled   = !variable.install_app
  depends_on = ["resource.k8s_config.base_setup"]

  source      = file("./k8s/base/templates/weather-tool-secret.tmpl")
  destination = "${data("k8s")}/weather-tool-secret.yaml"

  variables = {
    openweather_api_key = env("OPENWEATHER_API_KEY")
  }
}

resource "template" "ollama_host_secret" {
  disabled   = !variable.install_app
  depends_on = ["resource.k8s_config.base_setup"]

  source      = file("./k8s/base/templates/ollama-ui-secret.tmpl")
  destination = "${data("k8s")}/ollama-ui-secret.yaml"

  variables = {
    ollama_host = env("OLLAMA_HOST")
  }
}

resource "template" "vault_connection" {
  disabled   = !variable.install_app
  depends_on = ["resource.k8s_config.base_setup"]

  source      = file("./k8s/secure/templates/vault-connection.tmpl")
  destination = "${data("k8s")}/vault-connection.yaml"

  variables = {
    vault_ip = docker_ip()
  }
}

resource "k8s_config" "base_ui" {
  disabled   = !variable.install_app
  depends_on = ["resource.k8s_config.base_setup"]

  cluster = resource.k8s_cluster.demo

  paths = [
    "./k8s/base/exfil-server.yaml",
    "./k8s/base/chat-ui.yaml",
  ]

  wait_until_ready = true
}

resource "exec" "configure_vault_auth" {
  disabled = !variable.enable_app_vault_integration

  depends_on = ["resource.container.vault"]

  script = file("./scripts/app/setup-auth.sh")

  environment = {
    VAULT_ADDR   = "http://localhost:8200"
    VAULT_TOKEN  = "root"
    KEYCLOAK_URL = "http://localhost:8080"
    KUBECONFIG   = resource.k8s_cluster.demo.kube_config.path
  }
}

resource "exec" "configure_vault_database" {
  disabled = !variable.enable_app_vault_integration

  depends_on = ["resource.container.vault"]

  script = file("./scripts/app/setup-database.sh")

  environment = {
    VAULT_ADDR   = "http://localhost:8200"
    VAULT_TOKEN  = "root"
    KEYCLOAK_URL = "http://localhost:8080"
  }
}

resource "exec" "configure_vault_pki" {
  disabled = !variable.enable_app_vault_integration

  depends_on = ["resource.container.vault"]

  script = file("./scripts/app/setup-pki.sh")

  environment = {
    VAULT_ADDR   = "http://localhost:8200"
    VAULT_TOKEN  = "root"
    KEYCLOAK_URL = "http://localhost:8080"
  }
}

local "path" {
  value = variable.enable_app_vault_integration ? "secure" : "insecure"
}

resource "k8s_config" "app_setup" {
  disabled   = !variable.install_app
  depends_on = ["resource.k8s_config.base_setup"]

  cluster = resource.k8s_cluster.demo

  paths = [
    resource.template.weather_tool_secret.destination,
    resource.template.ollama_host_secret.destination,
    resource.template.vault_connection.destination,
    "./k8s/${local.path}",
  ]

  wait_until_ready = true
}

resource "ingress" "exfil_server" {
  port = 18080

  target {
    resource = resource.k8s_cluster.demo
    port     = 8080

    config = {
      service   = "exfil-server"
      namespace = "exfil-server"
    }
  }
}

resource "ingress" "chat_ui" {
  port = 18090

  target {
    resource = resource.k8s_cluster.demo
    port     = 80

    config = {
      service   = "chat-ui"
      namespace = "chat-ui"
    }
  }
}