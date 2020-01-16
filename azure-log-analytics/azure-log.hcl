job "azure-log-analytics" {
  datacenters = ["dc1"]

  type = "system"

  group "default" {
    vault {
      policies = ["azure-log"]
    }
    count = 1
    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }
    task "azure-alo" {
      driver = "docker"
      config {
        image = "microsoft/oms"
        port_map {
          tcp = 25225
        }
        hostname = "hostname"
        volumes = [
            "/var/run/docker.sock:/var/run/docker.sock",
            "/var/lib/docker/containers:/var/lib/docker/containers",
        ]
        
      }
      
      resources {
        network {
            port "tcp" { static = "25225" }
          }
      }

      service {
        name = "Azure-ALO"
        port = "tcp"
        tags = ["monitoring"]
        check {
          name = "Azure Log Analytics TCP check"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }

      template {
        data = <<EOH
WSID="{{with secret "secret/azure/logs/wsid"}}{{.Data.value}}{{end}}"
KEY="{{with secret "secret/azure/logs/key"}}{{.Data.value}}{{end}}"
EOH

        destination = "/secrets/mongo-uri.env"
        env = true
      }

    }


  }
}





