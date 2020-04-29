job "telegraf" {
  datacenters = ["dc1"]

  group "telegraf" {

    vault {
      policies = ["system_services"]
    }

    restart {
      mode = "delay"
    }


    task "telegraf" {
      driver = "docker"

      template {
        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/telegraf.conf"
        data = <<EOH

[global_tags]

[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false

[[outputs.prometheus_client]]
  listen = ":9273"
  metric_version = 2
  path = "/metrics"


[[inputs.mongodb]]

  servers = [ "{{with secret "secret/mongo/system_services/servers"}}{{.Data.primary}}{{end}}", 
              "{{with secret "secret/mongo/system_services/servers"}}{{.Data.backup_1}}{{end}}", 
              "{{with secret "secret/mongo/system_services/servers"}}{{.Data.backup_2}}{{end}}" ]

  gather_perdb_stats = true
  gather_col_stats = true

[[inputs.consul]]
  address = "https://uphsvlndc155.uphs.upenn.edu:8500"
  scheme = "https"

  insecure_skip_verify = true
  tag_delimiter = ":"
EOH
      }
      
      config {
        image = "telegraf"

        volumes = [
          "local/telegraf.conf:/etc/telegraf/telegraf.conf"
        ]
        port_map {
          http = 9273
        }
      }

      resources {
        network {
            port "http" { static = "9273" }
          }
      }

      service {
        name = "telegraf"
        port = "http"
        tags = ["monitoring"]
        check {
          name = "telegraf UI TCP Check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
    }

  }
}


