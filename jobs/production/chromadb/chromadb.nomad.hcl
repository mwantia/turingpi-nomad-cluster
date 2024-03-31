job "chromadb" {
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
      name = "chromadb"
      port = 8000

      meta {
        envoy_port = "${NOMAD_HOST_PORT_envoy}"
        envoy_path = "/metrics"
      }

      connect {
        sidecar_service {
          proxy {
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
        path     = "/api/v1/heartbeat"
        interval = "30s"
        timeout  = "2s"
      }
    }

    volume "data" {
      type            = "csi"
      read_only       = false
      source          = "chromadb-nfs-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "service" {
      driver = "docker"
      user   = "root"

      volume_mount {
        volume      = "data"
        destination = "/data"
        read_only   = false
      }

      config {
        image = "chromadb/chroma:latest"
      }

      template {
        data        = <<-EOH
        IS_PERSISTENT     = "true"
        PERSIST_DIRECTORY = "/data"
        EOH
        change_mode = "restart"
        destination = "secrets/file.env"
        env         = true
      }
      
      resources {
        cpu    = 1024
        memory = 2048
      }
    }

    ephemeral_disk {
      size = 150
    }
  }

  group "gateway" {
    network {
      mode = "bridge"

      port "envoy" { }

      port "inbound" {
        static = 8000
        to     = 8000
      }
    }

    service {
      name = "chromadb-gateway"
      port = "inbound"

      meta {
        envoy_port  = "${NOMAD_HOST_PORT_envoy}"
        envoy_path  = "/metrics"
      }

      connect {
        gateway {
          proxy {
            config {
              envoy_prometheus_bind_addr = "0.0.0.0:${NOMAD_HOST_PORT_envoy}"
            }
          }

          ingress {
            listener {
              port = 8000

              service {
                name = "chromadb"
              }
            }
          }
        }
      }
    }
    
    ephemeral_disk {
      size = 150
    }
  }
}