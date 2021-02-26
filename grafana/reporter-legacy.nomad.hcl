job "reporter" {
  datacenters = ["dc1"]

  meta {
    NAMESPACE = "staging"
  }

  group "default" {

    restart {
      mode = "delay"
    }

    task "reporter" {
      driver = "docker"

      env {
        HOST_ADDR = "${attr.unique.network.ip-address}"
      }

      config {
        args = ["-ip", "grafana.service.consul:3000"]
        image = "izakmarais/grafana-reporter"
        dns_servers = ["127.0.0.1", "${HOST_ADDR}"]
        port_map {
          reporter_http = 8686
        }
        // volumes = [
        //   "/deploy/reporter-data/provisioning/datasources:/etc/grafana/provisioning/datasources"
        // ]
      }
      resources {
        network {
            port "reporter_http" { static = "8686" }
          }
      }
      service {
        name = "reporter"
        port = "reporter_http"
        tags = ["ui"]
        check {
          name = "reporter UI TCP Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }


  }
}


