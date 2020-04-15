job "loki" {
  datacenters = ["dc1"]
  type        = "service"

  group "loki" {
    count = 1
  constraint {
    attribute = "${attr.unique.network.ip-address}"
    value = "170.166.23.4"
  }
    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "loki" {

      template {
        destination   = "/etc/loki/loki.yml"
        change_mode = "signal"
        change_signal = "SIGHUP"
        data = <<EOH

{{key "monitoring/loki.yml"}}

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
          "/deploy/loki-data:/loki"
        ]

        port_map {
          loki_port = 3100
        }
      }

      resources {
        cpu    = 300
        memory = 512

        network {
          mbits = 1
          port  "http" { static = "3100" }
        }
      }

      service {
        name = "loki"
        port = "http"
        tags = ["monitoring"]
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