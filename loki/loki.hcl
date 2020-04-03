job "loki" {
  datacenters = ["dc1"]
  type        = "service"

  group "loki" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "loki" {
      driver = "docker"

      config {
        image = "grafana/loki:master"

        args = [
          "-config.file",
          "/etc/loki/local-config.yaml",
        ]

        port_map {
          loki_port = 3100
        }
      }

      resources {
        cpu    = 50
        memory = 32

        network {
          mbits = 1
          port  "http" { static = "3100" }
        }
      }

      service {
        name = "loki"
        port = "http"
        tags = ["loki", "ui"]
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}