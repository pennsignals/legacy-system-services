job "prometheus" {
  datacenters = ["dc1"]

  group "prometheus" {

    restart {
      mode = "delay"
    }

    task "pushgateway" {
      driver = "docker"
      config {
        image = "prom/pushgateway"
        port_map {
          http = 9091
        }
      }

      resources {
        network {
            port "http" { static = "9091" }
          }
      }

      service {
        name = "pushgateway"
        port = "http"
        tags = ["prometheus", "metrics", "ui"]
        check {
          type     = "tcp"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
    
    task "prometheus" {

      env {
        CONSUL_ADDR = "https://uphsvlndc155.uphs.upenn.edu:8500"
      }

      template {
        change_mode = "noop"
        destination = "local/docker_alert.yml"
        data = <<EOH

{{key "monitoring/alert_rules/docker_alert.yml"}}

EOH
      }
      template {
        change_mode = "noop"
        destination = "local/node_alert.yml"
        data = <<EOH

{{key "monitoring/alert_rules/node_alert.yml"}}

EOH
      }
      template {
        change_mode = "noop"
        destination = "local/prometheus_alert.yml"
        data = <<EOH

{{key "monitoring/alert_rules/prometheus_alert.yml"}}

EOH
      }
      template {
        change_mode = "noop"
        destination = "local/promtail_alert.yml"
        data = <<EOH

{{key "monitoring/alert_rules/promtail_alert.yml"}}

EOH
      }
      template {
        change_mode = "noop"
        destination = "local/service_alert.yml"
        data = <<EOH

{{key "monitoring/alert_rules/service_alert.yml"}}

EOH
      }

      template {
        destination   = "local/prometheus.yml"
        change_mode   = "noop"
        data = <<EOH
global:
  scrape_interval:     15s 
  external_labels:
    monitor: 'codelab-monitor'

alerting:
  alertmanagers:
  - consul_sd_configs:
    - server: {{ env "CONSUL_ADDR" }}
      scheme: "https"
      tls_config:
        insecure_skip_verify: true
      services: ['alertmanager']

# Rules and alerts are read from the specified file(s)
rule_files:
 - docker_alert.yml
 - node_alert.yml
 - prometheus_alert.yml
 - promtail_alert.yml
 - service_alert.yml

scrape_configs:

  - job_name: 'alertmanager'

    consul_sd_configs:
    - server: {{ env "CONSUL_ADDR" }}
      scheme: "https"
      tls_config:
        insecure_skip_verify: true
      services: ['alertmanager']

  - job_name: 'nomad_metrics'

    consul_sd_configs:
    - server: {{ env "CONSUL_ADDR" }}
      scheme: "https"
      tls_config:
        insecure_skip_verify: true
      services: ['nomad-client', 'nomad']

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep

    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']


  - job_name:       'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

{{ range services }}{{if in .Tags "monitoring"}}
  - job_name: {{ .Name }}
    scrape_interval: 5s
    static_configs:
      - targets: [{{range $index, $service := service .Name }}{{if ne $index 0}},{{end}}'{{$service.Address}}:{{$service.Port}}'{{end}}]
        labels:
          group: 'monitoring'
{{end}}{{ end }}

{{ range services }}{{if in .Tags "metrics"}}
  - job_name: {{ .Name }}
    scrape_interval: 5s
    {{ range service .Name }}static_configs:
    - targets: ['{{.Address }}:{{.Port}}']
      labels:
        group: 'application'
        app: '{{ .Name}}'{{end}}
{{end}}{{ end }}
EOH

      }
      driver = "docker"
      config {
        image = "prom/prometheus"
        volumes = [
          "local/:/etc/prometheus/"
        ]
        port_map {
          http = 9090
        }
      }

      resources {
        cpu    = 200
        memory = 2048
        network {
            port "http" { static = "9090" }
          }
      }

      service {
        name = "prometheus"
        port = "http"
        tags = ["prometheus","ui"]
        check {
          name     = "prometheus_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }

    }

  }
}


