job "telegraf" {
  datacenters = ["dc1"]

  group "telegraf" {

    restart {
      mode = "delay"
    }


    task "telegraf" {
      driver = "docker"

      template {
        change_mode = "noop"
        destination = "local/telegraf.conf"
        data = <<EOH

{{key "monitoring/telegraf.conf"}}

EOH
      }

      template {
        data = <<EOH
MONGO_URI="{{with secret "secret/mongo/vent_integration/uri"}}{{.Data.value}}{{end}}"
EOH
        destination = "/secrets/.env"
        env         = true
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


