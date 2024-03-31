job "openai" {
  datacenters = [ "*" ]
  region      = "global"

  namespace   = "production"
  node_pool   = "turing-rk1"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }
  
  group "servers" {
    network {
      mode = "bridge"

      port "envoy" { }
    }

    service {
      name = "openai"
      port = 8080
      tags = [
        "prod", "traefik.enable=true", "traefik.location=private,public", 
        "traefik.http.routers.openai.tls.certresolver=lets-encrypt"
      ]

      meta {
        envoy_port = "${NOMAD_HOST_PORT_envoy}"
        envoy_path = "/metrics"

        app_name        = "OpenAI"
        app_description = "OpenAI Web-UI Plattform"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "ollama"
              local_bind_port  = 11434
            }

            config {
              envoy_prometheus_bind_addr = "0.0.0.0:${NOMAD_HOST_PORT_envoy}"
            }
          }
        }
      }
    }

    volume "data" {
      type            = "csi"
      read_only       = false
      source          = "openai-nfs-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "service" {
      driver = "docker"
      user   = "root"

      config {
        image = "ghcr.io/open-webui/open-webui:main"
      }

      volume_mount {
        volume      = "data"
        destination = "/app/backend/data"
        read_only   = false
      }

      template {
        data        = <<-EOH
        OLLAMA_API_BASE_URL = "http://{{ env "NOMAD_UPSTREAM_ADDR_ollama" }}/api"
        WEBUI_SECRET_KEY = "NOTREQUIRED"
        EOH
        change_mode = "restart"
        destination = "secrets/file.env"
        env         = true
      }

      resources {
        cpu    = 512
        memory = 512
      }
    }

    ephemeral_disk {
      size = 150
    }
  }
}