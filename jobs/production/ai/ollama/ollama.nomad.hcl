job "ollama" {
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
      name = "ollama"
      port = 11434

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
        path     = "/api/version"
        interval = "30s"
        timeout  = "2s"
      }
    }

    ephemeral_disk {
      size = 150
    }

    volume "data" {
      type            = "csi"
      read_only       = false
      source          = "ollama-nfs-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "service" {
      driver = "docker"
      user   = "root"

      volume_mount {
        volume      = "data"
        destination = "/root/.ollama"
        read_only   = false
      }

      config {
        image = "ollama/ollama:latest"
        privileged = true
      }

      action "list-models" {
        command = "ollama"
        args    = [ "list" ]
      }
      
      resources {
        cpu    = 4096
        memory = 8192
      }
    }
  }

  group "gateway" {
    network {
      mode = "bridge"

      port "envoy" { }

      port "inbound" {
        static = 11434
        to     = 11434
      }
    }

    service {
      name = "ollama-gateway"
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
              port = 11434

              service {
                name = "ollama"
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