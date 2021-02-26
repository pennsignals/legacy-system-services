job "promtail" {
  datacenters = ["dc1"]
  type        = "system"

  meta {
    NAMESPACE = "production"
  }
  
  group "default" {
    count = 1

   restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    network {
      mode = "host"  
      port "promtail_http" { static = 9080 }
    }
    task "promtail" {
      user = "root"
      driver = "docker"

      env {
        NOMAD_NODE = "${attr.unique.hostname}"
        HOST_ADDR = "${attr.unique.network.ip-address}"
        CONSUL_ADDR = "consul.service.consul:8500"
        ENVIRONMENT = "production"
      }
        template {
          destination = "./config/promtail.yml"
          change_mode = "signal"
          change_signal = "SIGHUP"
          data = <<EOH
server:
    http_listen_port: 9080
    grpc_listen_port: 0 
  
positions:
    filename: /tmp/promtail/positions.yaml

client:
  url: 'http://{{ with service "loki" }}{{ with index . 0 }}{{ .Address }}{{ end }}{{ end }}:3100/loki/api/v1/push'

scrape_configs:

- job_name:  docker_all
  static_configs:
  - targets:
      - localhost
    labels:
      job: docker_all
      app: docker_all
      __path__: /var/lib/docker/containers/*/*log

- job_name:  pennsignals_docker
  static_configs:
  - targets:
      - localhost
    labels:
      job: pennsignals_docker
      app: pennsignals_docker
      __path__: /var/lib/docker/containers/*/*log

  pipeline_stages:
  - match:
      selector: '{job="pennsignals_docker"} |~ "- \\w+ -"'
      stages:
      - regex:
          expression: '(?P<app_time>[^ ]+ [^ ]+)[^a-z]+(?P<service>\S+)\W+(?P<level>\w+)\W+(?P<message>[^{]+)(?P<data>.*)'
      - labels:
          service: 
          level:
          message:
      - output:
          source: data

- job_name: nomad_sd_logs

  consul_sd_configs:
  - server: '{{env "HOST_ADDR"}}:8500'
    scheme: "http"
    tls_config:
      insecure_skip_verify: true
    tags: ['{{env "ENVIRONMENT"}}']

  relabel_configs:

    - source_labels: [nomad_namespace]
      target_label: nomad_namespace
      replacement: '{{env "ENVIRONMENT"}}'

    - source_labels: [__meta_consul_tags]
      target_label: tags

    - source_labels: [__meta_consul_node]
      target_label: host

    - source_labels: [job]
      target_label: job
      replacement: nomad_sd_logs

    - source_labels: [__meta_consul_node]
      regex: {{env "NOMAD_NODE"}}
      action: keep

    - source_labels: [__meta_consul_service]
      target_label: consul_service

    - source_labels: [__meta_consul_service_metadata_external_source]
      target_label: external_source

    - source_labels: [__meta_consul_service_id]
      regex: '_nomad-task-(.{36}).*'
      target_label: alloc_id

    - source_labels: [__meta_consul_service_id]
      separator: ;
      regex: '_nomad-task-.{36}-([^-]*)-.*'
      target_label: __tmp_filename

    - source_labels: [alloc_id]
      target_label: __tmp_file_dir
      replacement: "/var/lib/nomad/alloc/$1/alloc/logs"

    - source_labels: [__tmp_file_dir, __tmp_filename]
      separator: '/'
      target_label: __path__
      replacement: "$1$2*"        

  pipeline_stages:

  - match:
      selector: '{job="nomad_sd_logs"}'
      stages:
      - labels:
          job: all_sd_logs

EOH

        }


      config {
        image = "grafana/promtail:2.1.0"
        args = [
          "-config.file",
          "/etc/promtail/promtail.yml"
        ]

        volumes = [
          "./config:/etc/promtail",
          "/deploy/promtail-data/${NOMAD_NODE}:/tmp/promtail",
          "/var/run:/var/run:ro",
          "/sys:/sys:ro", 
          "/var/lib/docker/:/var/lib/docker:ro",
          "/var/lib/nomad/alloc:/var/lib/nomad/alloc:ro"       

        ]

        dns_servers = ["127.0.0.1", "${HOST_ADDR}"]
        ports = [ "promtail_http" ]


      }

      resources {
        cpu    = 100
        memory = 256

      }

      service {
        name = "promtail"
        port = "promtail_http"
        tags = ["monitoring", "${ENVIRONMENT}"]
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