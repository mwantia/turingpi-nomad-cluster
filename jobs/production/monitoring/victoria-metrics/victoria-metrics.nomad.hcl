job "victoria-metrics" {
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

      port "http" {
        to     = "4828"
        static = "4828"
      }
    }

    service {
      name = "victoria-metrics"
      task = "service"
      port = "http"

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
                local_path_port = 4828
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
      source          = "victoria-metrics-nfs-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "service" {
      driver = "docker"
      user   = "root"

      config {
        image   = "victoriametrics/victoria-metrics:latest"
        args    = [ "--storageDataPath=/data", "--httpListenAddr=:4828", "--retentionPeriod=365d" ]
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