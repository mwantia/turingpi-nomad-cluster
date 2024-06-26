job "victoria-logs" {
  datacenters = [ "*" ]
  region      = "global"
  type        = "system"

  namespace   = "production"
  node_pool   = "all"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  constraint {
    distinct_property = "${meta.node.site}"
    value             = "1"
  }

  group "servers" {
    network {
      mode = "bridge"

      port "metrics" { }
      port "envoy"   { }
    }

    service {
      name = "victoria-logs"
      task = "service"
      tags = [ "traefik.enable=true", "traefik.location=production" ]
      port = 9428

      meta {
        metrics_path = "/metrics"
        metrics_port = "${NOMAD_HOST_PORT_metrics}"

        envoy_port = "${NOMAD_HOST_PORT_envoy}"
        envoy_path = "/metrics"
      }

      connect {
        sidecar_service {
          proxy {
            expose {
              path {
                path            = "/metrics"
                protocol        = "http"
                local_path_port = 9428
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
        name     = "health"
        path     = "/-/healthy"
        interval = "30s"
        timeout  = "2s"
      }
    }

    volume "data" {
      type            = "csi"
      read_only       = false
      source          = "victoria-logs-nfs-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "service" {
      driver = "docker"
      user   = "root"

      config {
        image   = "victoriametrics/victoria-logs:latest"
        args    = [ "--storageDataPath=/data", "--httpListenAddr=:9428", "--retentionPeriod=365d" ]
      }

      volume_mount {
        volume      = "data"
        destination = "/data"
        read_only   = false
      }
      
      resources {
        cpu    = 512
        memory = 1024
      }
    }

    ephemeral_disk {
      size    = 150
    }
  }
}