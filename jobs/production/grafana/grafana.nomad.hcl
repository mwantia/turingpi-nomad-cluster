job "grafana" {
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

      port "envoy"   { }
    }

    service {
      name = "grafana"
      task = "service"
      tags = [ "traefik.enable=true", "traefik.location=production" ]
      port = 3000

      meta {
        envoy_port = "${NOMAD_HOST_PORT_envoy}"
        envoy_path = "/metrics"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "victoria-metrics"
              local_bind_port  = 9090
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
        path     = "/api/health"
        interval = "30s"
        timeout  = "3s"
      }
    }

    volume "data" {
      type            = "csi"
      read_only       = false
      source          = "grafana-nfs-data"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "service" {
      driver = "docker"
      user   = "root"

      config {
        image = "grafana/grafana:latest"

        mount {
          type = "bind"
          target = "/etc/grafana/grafana.ini"
          source = "local/grafana.ini"
          readonly = true

          bind_options {
            propagation = "rshared"
          }
        }
      }

      volume_mount {
        volume      = "data"
        destination = "/data"
        read_only   = false
      }

      template {
        change_mode = "restart"
        destination = "secrets/file.env"
        data        = <<-EOH
        GF_LOG_LEVEL               = "WARN"
        GF_LOG_MODE                = "console"
        GF_SERVER_HTTP_PORT        = "3000"
        GF_PATHS_DATA              = "/data"
        GF_PATHS_PLUGINS           = "/local/plugins"
        GF_PATHS_PROVISIONING      = "/local/provisioning"
        GF_SECURITY_ADMIN_PASSWORD = "Grafana2023#!"
        EOH
        env         = true
      }

      template {
        change_mode = "noop"
        destination = "local/grafana.ini"
        data        = <<EOH
        [auth.proxy]
        enabled = true
        header_name = Remote-User
        header_property = username
        auto_sign_up = true
        headers = Groups:Remote-Group
        enable_login_token = false
        EOH
      }

      template {
        change_mode = "noop"
        destination = "/local/provisioning/dashboards/dashboards.yaml"
        data        = <<-EOH
        apiVersion: 1
        providers:
        - name: dashboards
          type: file
          updateIntervalSeconds: 30
          options:
            foldersFromFilesStructure: true
            path: /local/provisioning/dashboards
        EOH
      }

      template {
        change_mode = "noop"
        destination = "/local/provisioning/datasources/datasources.yaml"
        data        = <<-EOH
        apiVersion: 1
        datasources:
          - name: prometheus
            type: prometheus
            access: proxy
            url: 'http://{{ env "NOMAD_UPSTREAM_ADDR_victoria_metrics" }}'
        EOH
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