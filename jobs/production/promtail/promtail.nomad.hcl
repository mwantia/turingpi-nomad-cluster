job "promtail" {
  datacenters = [ "*" ]
  region      = "global"
  type        = "system"

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

      port "http" {
        to     = 9080
        static = 9080
      }

      port "syslog" {
        to     = 514
        static = 514
      }
    }

    service {
      name = "promtail"
      task = "service"
      tags = [ ]
      port = "http"

      meta {
        metrics_path = "/metrics"
        metrics_port = "${NOMAD_HOST_PORT_http}"

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
                local_path_port = 9080
                listener_port   = "metrics"
              }
            }

            upstreams {
              destination_name = "victoria-logs"
              local_bind_port  = 9428
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
        name     = "ready"
        path     = "/ready"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "service" {
      driver = "docker"

      config {
        image   = "grafana/promtail:2.8.2"
        args    = [ "-config.file=/local/config.yml" ]

        mount {
          type = "bind"
          target = "/allocs"
          source = "/srv/nomad/data/alloc"
          readonly = true

          bind_options { 
            propagation = "rshared" 
          }
        }

        mount {
          type = "bind"
          target = "/etc/ssl/certs/rootca.crt"
          source = "secrets/rootca.crt"
          readonly = true

          bind_options {
            propagation = "rshared"
          }
        }
      }

      env {
        HOSTNAME = "${attr.unique.hostname}"
      }

      template {
        destination = "secrets/rootca.crt"
        change_mode = "noop"
        data        = <<-EOH
        {{- with secret "certificates/rootca" }}
        {{ .Data.data.crt }}
        {{- end }}
        EOH
      }

      template {
        data        = <<-EOH
        server:
          http_listen_address: 0.0.0.0
          http_listen_port: 9080
        
        positions:
          filename: /alloc/tmp/positions.yaml
        
        clients:
          - url: http://{{ env "NOMAD_UPSTREAM_ADDR_victoria_logs" }}/insert/loki/api/v1/push?_stream_fields=instance,host,service,site,location
        
        scrape_configs:      
          - job_name: syslog-services
            syslog:
              listen_address: 0.0.0.0:514

          - job_name: dynamic-services
            consul_sd_configs:
              - server: '100.79.63.127:8501'
                token: '{{ env "CONSUL_TOKEN" }}'
                scheme: https
            relabel_configs:
              - source_labels: [ __meta_consul_node ]
                action: keep
                regex: '{{ env "attr.unique.hostname" }}'
              - source_labels: [ __meta_consul_service ]
                action: drop
                regex: ([nomad|nomad\-client]*)
              - source_labels: [ __meta_consul_service ]
                action: drop
                regex: (.+)-sidecar-proxy
              - source_labels: [ __meta_consul_node ]
                target_label: host
              - source_labels: [ __meta_consul_service_metadata_external_source ]
                target_label: source
                regex: (.*)
                replacement: '$1'
              - source_labels: [ __meta_consul_service_id ]
                regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
                target_label:  task_id
                replacement: '$1'
              - source_labels: [ __meta_consul_service ]
                regex: (.*)
                target_label: service
              - source_labels: [ __meta_consul_metadata_site ]
                regex: (.*)
                target_label: site
              - source_labels: [ __meta_consul_metadata_location ]
                regex: (.*)
                target_label: location
              - source_labels: [ __meta_consul_service_id ]
                regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
                target_label: __path__
                replacement: '/allocs/$1/alloc/logs/*std*.{?,??}'
        EOH
        change_mode = "noop"
        destination = "local/config.yml"
      }

      identity {
        env = true
      }

      consul { 

      }

      vault {

      }
      
      resources {
        cpu    = 128
        memory = 128
      }
    }

    ephemeral_disk {
      size    = 150
    }
  }
}