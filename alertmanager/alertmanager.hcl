job "alertmanager" {
  datacenters = ["dc1"]
  type = "service"

  group "alerting" {
    count = 1
    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }
    ephemeral_disk {
      size = 300
    }

    task "alertmanager" {
      template {
        destination   = "/etc/alertmanager/alertmanager.yml"
        change_mode = "signal"
        change_signal = "SIGHUP"
        data = <<EOH

{{key "monitoring/alertmanager.yml"}}

EOH
      }
      driver = "docker"

      config {
        image = "prom/alertmanager:latest"
        port_map {
          alertmanager_ui = 9093
        }

        args = [
          "--config.file=/etc/alertmanager/alertmanager.yml",
          "--storage.path=/alertmanager",
        ]

        volumes = [
          "etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml",
        ]
      }
      resources {
        network {
          mbits = 10
          port "alertmanager_ui" {}
        }
      }
      service {
        name = "alertmanager"
        tags = ["urlprefix-/alertmanager strip=/alertmanager"]
        port = "alertmanager_ui"
        check {
          name     = "alertmanager_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
