job "grafana" {
  datacenters = ["dc1"]

  meta {
    NAMESPACE = "production"
  }

  group "default" {

    restart {
      mode = "delay"
    }

    network {
      mode = "host"
      port "grafana_http" { static = 3000 }
      port "loki_http" { static = 3100 }
    }

    task "grafana" {
      driver = "docker"

      env {
        HOST_ADDR = "${attr.unique.network.ip-address}"
        GF_PANELS_DISABLE_SANITIZE_HTML = "true"
      }

      config {
        image = "grafana/grafana:7.4.2"
        dns_servers = ["127.0.0.1", "${HOST_ADDR}"]
        ports = [ "grafana_http" ]
        volumes = [
          "/deploy/grafana-data/provisioning/datasources:/etc/grafana/provisioning/datasources"
        ]
      }

      service {
        name = "grafana"
        port = "grafana_http"
        tags = ["ui"]
        check {
          name = "grafana UI TCP Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }

    task "loki" {

      driver = "docker"

      config {
        image = "grafana/loki:2.1.0"
        ports = [ "loki_http" ]
        // args = [
        //   "-config.file",
        //   "/etc/loki/local-config.yaml",
        // ]

        volumes = [
          "/deploy/loki-data:/loki"
        ]

      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "loki"
        port = "loki_http"
        tags = ["ui"]
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


