job "grafana" {
  datacenters = ["dc1"]

  group "grafana" {

    restart {
      mode = "delay"
    }

    task "grafana" {
      driver = "docker"

      template {
        change_mode = "noop"
        destination = "/local/grafana.ini"
        data = <<EOH
{{key "pennsignals/grafana/grafana.ini"}}
EOH
      }
      config {
        image = "grafana/grafana-oss:8.2"

        volumes = [
          "/deploy/grafana-data:/var/lib/grafana",
          "/local/grafana.ini:/etc/grafana/grafana.ini"
        ]
        port_map {
          http = 3000
        }
      }

      resources {
        network {
            port "http" { static = "3000" }
          }
      }

      service {
        name = "grafana"
        port = "http"
        tags = ["ui"]
        check {
          name = "grafana UI TCP Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }

  }
}


