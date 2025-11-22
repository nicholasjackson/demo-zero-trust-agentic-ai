resource "k8s_config" "base_setup" {
  disabled = !variable.install_app

  depends_on = ["resource.helm.vault_operator"]

  cluster = resource.k8s_cluster.demo

  paths = [
    "./k8s/namespace.yaml",
  ]

  wait_until_ready = true
}

resource "template" "weather_tool_secret" {
  disabled = !variable.install_app

  source      = file("./k8s/templates/weather-tool-secret.tmpl")
  destination = "${data("k8s")}/weather-tool-secret.yaml"

  variables = {
    openweather_api_key = env("OPENWEATHER_API_KEY")
  }
}

resource "k8s_config" "exfil-server" {
  disabled = !variable.install_app

  cluster = resource.k8s_cluster.demo

  paths = [
    "./k8s/exfil-server.yaml",
  ]

  wait_until_ready = true
}

resource "k8s_config" "weather_setup" {
  disabled = !variable.install_app

  depends_on = ["resource.helm.vault_operator"]

  cluster = resource.k8s_cluster.demo

  paths = [
    resource.template.weather_tool_secret.destination,
    "./k8s/weather-agent.yaml",
    "./k8s/weather-tool.yaml",
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
      namespace = "agents"
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
      namespace = "agents"
    }
  }
}