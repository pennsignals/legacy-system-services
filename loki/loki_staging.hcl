job "loki_staging" {
  datacenters = ["dc1"]
  type        = "service"

  group "loki" {
    count = 1
  constraint {
    attribute = "${attr.unique.network.ip-address}"
    value = "170.166.23.5"
  }
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "loki" {

      template {
        destination   = "local/loki.yml"
        change_mode = "signal"
        change_signal = "SIGHUP"
        data = <<EOH

{{key "system_services/staging/loki.yml"}}

EOH

      }
      driver = "docker"

      config {
        image = "grafana/loki:master"

        args = [
          "-config.file",
          "/etc/loki/local-config.yaml",
        ]

        volumes = [
          "/deploy/loki-data_staging:/loki"
        ]

        port_map {
          loki_port = 3100
        }
      }

      resources {
        cpu    = 300
        memory = 2048

        network {
          mbits = 1
          port  "http" { static = "3100" }
        }
      }

      service {
        name = "loki-staging"
        port = "http"
        tags = ["monitoring", "staging", "ui"]
        check {
          name = "Loki TCP Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }
  }
}