job "promtail_staging" {
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
        NOMAD_NODE = "${attr.unique.hostname}"
        HOST_ADDR = "${attr.unique.network.ip-address}"
        CONSUL_ADDR = "https://uphsvlndc155.uphs.upenn.edu:8500",
      }
        template {
          destination = "./config/promtail.yml"
          change_mode = "signal"
          change_signal = "SIGHUP"
          data = <<EOH
server:
    http_listen_port: 9081
    grpc_listen_port: 0 
  
positions:
    filename: /tmp/promtail/{{ env "NOMAD_NODE" }}/positions.yaml
client:
  url: 'http://170.166.23.5:3100/loki/api/v1/push'

scrape_configs:

- job_name: nomad_sd_logs

  consul_sd_configs:
  - server: '{{env "HOST_ADDR"}}:8500'
    scheme: "https"
    tls_config:
      insecure_skip_verify: true
    tags: ['production']

  relabel_configs:

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
      replacement: '/var/nomad/alloc/${1}/alloc/logs/'    

    - source_labels: [__tmp_file_dir, __tmp_filename]
      separator: ''
      target_label: __path__
      replacement: '${1}${2}*'         
     

  pipeline_stages:
  - match:
      selector: '{job="nomad_sd_logs"} |~ "- (NOTSET|DEBUG|INFO|WARNING|ERROR|CRITICAL) -"'
      stages:
      - regex:
            expression: '(?P<app_time>[^ ]+ [^ ]+)[^a-z]+(?P<service>\S+)\W+(?P<level>\w+)[^{]+(?P<data>.*)'
      - labels:
          service: 
          level: 
          job: pennsignals_logs
      - output:
          source: data
      - metrics:
          service_INFO_messages_total:
              type: Counter
              description: "INFO messages from pennsignalls services containing payload"
              source: service
              config: 
                  match_all: true
                  action: inc  
EOH

        }


      config {
        image = "grafana/promtail"

        args = [
          "-config.file",
          "/etc/promtail/promtail.yml"
        ]

        volumes = [
          "./config:/etc/promtail",
          "/deploy/promtail-data:/tmp/promtail",
          "/var/run:/var/run:ro",
          "/sys:/sys:ro", 
          "/var/lib/docker/:/var/lib/docker:ro",
          "/var/nomad/alloc/:/var/nomad/alloc:ro"       

        ]

        port_map {
          promtail_port = 9081
        }

      }

      resources {
        cpu    = 100
        memory = 256

        network {
          mbits = 1
          port  "http" { static = "9081" }
        }
      }

      service {
        name = "promtail-staging"
        port = "http"
        tags = ["monitoring", "staging"]
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