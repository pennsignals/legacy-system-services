job "prometheus" {
  datacenters = ["dc1"]

  group "prometheus" {

    restart {
      mode = "delay"
    }


    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana"
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


