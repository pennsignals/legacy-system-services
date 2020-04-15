job "promtail" {
  datacenters = ["dc1"]
  type        = "system"

  group "promtail" {
    count = 1

   restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    task "promtail" {
      driver = "docker"

        template {
          destination = "etc/promtail/promtail.yml"
          change_mode = "signal"
          change_signal = "SIGHUP"
          data = <<EOH

{{key "monitoring/promtail.yml"}}

EOH

        }
      env {
        CONSUL_IP = "https://uphsvlndc155.uphs.upenn.edu",
        CONSUL_PORT = "8500",
        CONSUL_ADDR = "https://uphsvlndc155.uphs.upenn.edu:8500",
        LOKI_IP = "http://loki.pennsignals.uphs.upenn.edu",
        LOKI_PORT = "3100",
        LOKI_ADDR = "http://170.166.23.4:3100"
      }

      config {
        image = "grafana/promtail:master"

        logging {
          type = "loki"
          config {
            loki-url="${LOKI_ADDR}/loki/api/v1/push",
            loki-retries=5,
            loki-batch-size=400
          }
        }

        args = [
          "-config.file",
          "/etc/promtail/promtail.yml"
        ]

        volumes = [
          "etc/promtail/promtail.yml:/etc/promtail/promtail.yml",
        ]

        port_map {
          promtail_port = 9080
        }

        volumes = [
            "/var/run/docker.sock:/var/run/docker.sock",
            "/run/log/journal/:/run/log/journal",
            "/var/log/journal:/var/log/journal",
            "/etc/machine-id:/etc/machine-id",
            "/:/rootfs:ro",
            "/var/run:/var/run:ro",
            "/sys:/sys:ro", 
            "/var/lib/docker/:/var/lib/docker:ro",
            "/dev/disk/:/dev/disk:ro",
            "/alloc/logs/:/alloc/logs:ro"
        ]
      }

      resources {
        cpu    = 100
        memory = 256

        network {
          mbits = 1
          port  "http" { static = "9080" }
        }
      }

      service {
        name = "promtail"
        port = "http"
        tags = ["monitoring"]
        check {

          name = "Promtail TCP Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }
  }
}