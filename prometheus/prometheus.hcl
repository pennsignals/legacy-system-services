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
      driver = "docker"
      config {
        image = "prom/prometheus"
        volumes = [
          "local/:/etc/prometheus/",
          "/deploy/prometheus-data:/prometheus"
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
          name = "prometheus UI TCP Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }

      env {
        GRAFANA_IP = "${NOMAD_ADDR_grafana_http}"
        PUSHGATEWAY_IP = "${NOMAD_ADDR_pushgateway_http}"
      }

      template {
  data = <<EOH
global:
  scrape_interval:     15s 
  external_labels:
    monitor: 'codelab-monitor'

scrape_configs:
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
        destination   = "local/prometheus.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

    }

  }
}


