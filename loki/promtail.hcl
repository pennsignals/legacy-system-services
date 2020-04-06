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
          "local/config.yaml"
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
            "/dev/disk/:/dev/disk:ro"
        ]
      }

      template {
        data = <<EOH

server:
    http_listen_port: 9080
    grpc_listen_port: 0 
  
positions:
    filename: /tmp/positions.yaml

client:
  url: '{{ env "LOKI_ADDR" }}/loki/api/v1/push'

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - "localhost"
    labels:
      job: varlogs
      app: testapp
      __path__: /alloc/logs/*

- job_name: journal
  journal:
    json: false
    max_age: 12h
    path: /var/log/journal
    labels:
      job: systemd-journal
  relabel_configs:
    - source_labels: ['__journal__systemd_unit']
      target_label: 'unit'

- job_name:  docker
  static_configs:
  - targets:
      - localhost
    labels:
      job: dockerlogs
      app: web_app
      __path__: /var/lib/docker/containers/*/*log

  pipeline_stages:
  - match:
      selector: '{app="web_app"} |~ "- [A-Z]+ -"'
      stages:
      - regex:
          expression: '^(?s)[^0-9]+(?P<time>[^ ]+ [^ ]+)[^a-z]+(?P<service>\S+)[ |-]+(?P<level>\S+)[ |-]+(?P<payload>.*)$'
      - labels:
          service:
          level:
      - output:
          source: payload

- job_name: syslog
  syslog:
    listen_address: 0.0.0.0:1514
    idle_timeout: 60s
    label_structured_data: yes
    labels:
      job: "syslog"
  relabel_configs:
    - source_labels: ['__syslog_message_hostname']
      target_label: 'host'

- job_name: 'nomad_metrics'

  consul_sd_configs:
  - server: '{{ env "CONSUL_ADDR" }}'
    services: ['nomad-client', 'nomad']

  relabel_configs:
  - source_labels: ['__meta_consul_tags']
    regex: '(.*)http(.*)'
    action: keep

EOH

        destination = "local/config.yaml"
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
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}