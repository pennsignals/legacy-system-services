job "node-exporter" {
  datacenters = ["dc1"]
  type = "system"

  meta {
    NAMESPACE = "production"
  }

  group "default" {
    count = 1
    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    network {
      mode = "host"  
      port "node_http" { static = 9100 }
    }

    task "node_exporter" {
      user = "root"
      driver = "docker"

      env {
        HOST_ADDR = "${attr.unique.network.ip-address}"
        ENVIRONMENT = "production"
      }

      config {
        image = "prom/node-exporter:v1.1.1"
        dns_servers = ["127.0.0.1", "${HOST_ADDR}"]
        ports = [ "node_http" ]
        volumes = [
            "/proc:/host/proc:ro",
            "/sys:/host/sys:ro",
            "/:/rootfs:ro",
        ]

      }

      resources {
        cpu    = 128
        memory = 128
      }

      service {
        name = "node-exporter"
        port = "node_http"
        tags = ["monitoring", "${ENVIRONMENT}"]
        check {
          name = "Node Exporter UI TCP Check"
          type = "http"
          path = "/metrics/"
          interval = "10s"
          timeout = "2s"
        }
      }
    }


  }
}