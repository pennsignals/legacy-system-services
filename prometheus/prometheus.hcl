job "prometheus" {
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
      port "prometheus_http" { static = 9090 }
    }

    task "prometheus" {
      user = "root"
      env {
        HOST_ADDR = "${attr.unique.network.ip-address}"
        CONSUL_ADDR = "consul.service.consul:8500"
        ENVIRONMENT = "staging"
      }

      template {
        destination   = "local/prometheus.yml"
        change_mode   = "noop"

        data = <<EOH
global:
  scrape_interval:     5s 
  evaluation_interval: 5s

scrape_configs:

  - job_name: 'nomad_metrics'

    scheme: http
    tls_config:
      insecure_skip_verify: true

    consul_sd_configs:
    - server: {{ env "CONSUL_ADDR" }}
      scheme: "http"
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

  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

  - job_name: monitoring_jobs
    consul_sd_configs:
      - server: {{ env "CONSUL_ADDR" }}
        scheme: "http"
        tls_config:
          insecure_skip_verify: true
        tags: ['monitoring']

    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: job

  - job_name: consul_monitoring  

    scheme: http
    tls_config:
      insecure_skip_verify: true

    consul_sd_configs:
      - server: {{ env "CONSUL_ADDR" }}
        scheme: "http"
        tls_config:
          insecure_skip_verify: true
        services: ['consul']

    relabel_configs:
      - source_labels: [__meta_consul_service]
        target_label: job

      - source_labels: ['__address__']
        separator:     ':'
        regex:         '(.*):(8300)'
        target_label:  '__address__'
        replacement:   '${1}:8500'
        action: replace


    metrics_path: /v1/agent/metrics
    params:
      format: ['prometheus']

        
EOH

      }
      driver = "docker"
      config {
        image = "prom/prometheus:v2.25.0"
        volumes = [
          "local/:/etc/prometheus/",
          "/deploy/prometheus-data:/prometheus"
        ]
        dns_servers = ["127.0.0.1", "${HOST_ADDR}"]
        ports = [ "prometheus_http" ]

      }

      resources {
        cpu    = 200
        memory = 2048
      }

      service {
        name = "prometheus"
        port = "prometheus_http"
        tags = ["prometheus","ui", "${ENVIRONMENT}"]
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


