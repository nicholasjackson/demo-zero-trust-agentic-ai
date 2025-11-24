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

resource "k8s_config" "base-server" {
  disabled   = !variable.install_app
  depends_on = ["resource.k8s_config.base_setup"]

  cluster = resource.k8s_cluster.demo

  paths = [
    "./k8s/base/exfil-server.yaml",
    "./k8s/base/chat-ui.yaml",
  ]

  wait_until_ready = true
}

resource "k8s_config" "app_setup" {
  disabled   = !variable.install_app
  depends_on = ["resource.k8s_config.base_setup"]

  cluster = resource.k8s_cluster.demo

  paths = [
    resource.template.weather_tool_secret.destination,
    resource.template.ollama_host_secret.destination,
    "./k8s/insecure/weather-agent.yaml",
    "./k8s/insecure/weather-tool.yaml",
    "./k8s/insecure/customer-agent.yaml",
    "./k8s/insecure/customer-tool.yaml",
    "./k8s/insecure/customer-tool-db.yaml",
  ]

  wait_until_ready = true
}

resource "ingress" "weather_agent" {
  port = 18123

  target {
    resource = resource.k8s_cluster.demo
    port     = 8123

    config = {
      service   = "weather-agent"
      namespace = "weather-agent"
    }
  }
}

resource "ingress" "customer_agent" {
  port = 18124

  target {
    resource = resource.k8s_cluster.demo
    port     = 8124

    config = {
      service   = "customer-agent"
      namespace = "customer-agent"
    }
  }
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