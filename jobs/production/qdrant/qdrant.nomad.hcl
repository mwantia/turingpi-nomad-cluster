job "qdrant" {
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

      port "metrics" { }
      port "envoy"   { }
    }

    service {
      name = "qdrant"
      port = 6333
      tags = [
        "traefik.enable=true", "traefik.location=private,public", 
        "traefik.http.routers.qdrant.tls.certresolver=lets-encrypt"
      ]

      meta {
        metrics_path = "/metrics"
        metrics_port = "${NOMAD_HOST_PORT_metrics}"

        envoy_port = "${NOMAD_HOST_PORT_envoy_http}"
        envoy_path = "/metrics"

        app_name        = "Qdrant"
        app_description = "Vector Database"
        app_icon        = "https://avatars.githubusercontent.com/u/73504361?s=200&v=4"
      }

      connect {
        sidecar_service {
          proxy {
            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 6333
                listener_port   = "metrics"
              }
            }

            config {
              envoy_prometheus_bind_addr = "0.0.0.0:${NOMAD_HOST_PORT_envoy}"
            }
          }
        }
      }
      
      check {
        expose   = true
        type     = "http"
        name     = "live"
        path     = "/livez"
        interval = "10s"
        timeout  = "3s"
      }
    }

    volume "data" {
      type            = "csi"
      read_only       = false
      source          = "qdrant-nfs-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "service" {
      driver = "docker"

      volume_mount {
        volume      = "data"
        destination = "/qdrant/storage"
        read_only   = false
      }

      config {
        image = "qdrant/qdrant:latest"
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