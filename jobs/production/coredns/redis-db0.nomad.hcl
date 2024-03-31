job "redis-db0" {
  datacenters = [ "*" ]
  region      = "global"

  namespace   = "production"
  node_pool   = "all"

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
      name = "redis-db0"
      task = "service"
      port = 6379

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
                local_path_port = 9121
                listener_port   = "metrics"
              }
            }

            config {
              envoy_prometheus_bind_addr = "0.0.0.0:${NOMAD_HOST_PORT_envoy}"
            }
          }
        }
      }
    }

    task "service" {
      driver = "docker"

      config {
        image   = "redis:latest"
        args    = [ "--include", "/local/redis.conf" ]
        command = "redis-server"
      }

      template {
        destination = "local/redis.conf"
        change_mode = "noop"
        data        = <<-EOH
        save 60 100
        rdbcompression yes
        dbfilename dump.rdb
        dir /alloc/data

        appendonly yes
        appendfilename redis.aof
        
        maxmemory 100mb
        maxmemory-policy allkeys-lru
        EOH
      }

      action "service-info" {
        command = "redis-cli"
        args    = [ "INFO" ]
      }

      action "scan-keys" {
        command = "redis-cli"
        args    = [ "SCAN", "0", "MATCH", "\"*\"", "COUNT", "1000" ]
      }

      action "list-keys" {
        command = "redis-cli"
        args    = [ "KEYS", "*" ]
      }
      
      resources {
        cpu    = 128
        memory = 128
      }
    }

    task "exporter" {
      driver = "docker"

      lifecycle {
        hook = "poststart"
      }

      config {
        image = "oliver006/redis_exporter:latest"
      }

      resources {
        cpu    = 128
        memory = 128
      }
    }

    ephemeral_disk {
      size    = 150
      migrate = true
      sticky  = true
    }
  }
}