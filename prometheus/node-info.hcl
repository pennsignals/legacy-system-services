job "system-monitoring" {
  datacenters = ["dc1"]

  type = "system"

  group "default" {
    count = 1
    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }
    task "cadvisor" {
      driver = "docker"
      config {
        image = "google/cadvisor"
        port_map {
          http = 8080
        }
        volumes = [
            "/:/rootfs:ro",
            "/var/run:/var/run:ro",
            "/sys:/sys:ro",
            "/var/lib/docker/:/var/lib/docker:ro",
            "/dev/disk/:/dev/disk:ro"
        ]
      }
      
      resources {
        network {
            port "http" { static = "8080" }
          }
      }

      service {
        name = "cadvisor"
        port = "http"
        tags = ["monitoring"]
        check {
          name = "cadvisor UI TCP Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }


    task "node_exporter" {
      driver = "docker"
      config {
        image = "prom/node-exporter"
        port_map {
          http = 9100
        }
        volumes = [
            "/proc:/host/proc:ro",
            "/sys:/host/sys:ro",
            "/:/rootfs:ro",
        ]

      }

      resources {
        cpu    = 50
        memory = 100
        network {
          port "http" { static = "9100" }
        }
      }

      service {
        name = "node-exporter"
        port = "http"
        tags = ["monitoring"]
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