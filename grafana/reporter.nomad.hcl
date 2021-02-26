job "reporter" {
  datacenters = ["dc1"]

  meta {
    NAMESPACE = "staging"
  }

  group "default" {

    restart {
      mode = "delay"
    }

    network {
      mode = "host"
      port "reporter_http" { static = 8686 }
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
        ports = [ "reporter_http" ]
        // volumes = [
        //   "/deploy/reporter-data/provisioning/datasources:/etc/grafana/provisioning/datasources"
        // ]
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


