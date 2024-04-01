job "vm-agent" {
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

  constraint {
    distinct_property = "${meta.node.location}"
    value             = "1"
  }

  group "servers" {
    network {
      mode = "bridge"

      port "http" {
        to     = "4829"
        static = "4829"
      }
    }

    service {
      name = "vm-agent"
      task = "service"
      port = "http"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "victoria-metrics"
              local_bind_port  = 4828
            }

            config {
              envoy_prometheus_bind_addr = "127.0.0.1:9001"
            }
          }
        }
      }

      check {
        expose   = false
        type     = "http"
        name     = "health"
        path     = "/-/healthy"
        interval = "30s"
        timeout  = "2s"
      }
    }

    task "service" {
      driver = "docker"

      config {
        image   = "victoriametrics/vmagent:latest"
        args    = [ "--remoteWrite.url=http://${NOMAD_UPSTREAM_ADDR_victoria_metrics}/api/v1/write", 
          "--httpListenAddr=0.0.0.0:${NOMAD_PORT_http}", "--promscrape.config=/local/prometheus.yml", "--promscrape.config.strictParse=false" ]

        mount {
          type = "bind"
          target = "/etc/ssl/certs/rootCA.crt"
          source = "secrets/rootCA.crt"
          readonly = true

          bind_options {
            propagation = "rshared"
          }
        }
      }

      template {
        destination = "secrets/rootCA.crt"
        change_mode = "noop"
        data        = <<-EOH
        {{- with secret "certificates/rootca" }}
        {{ .Data.data.crt }}
        {{- end }}
        EOH
      }

      template {
        destination = "local/prometheus.yml"
        change_mode = "noop"
        data        = <<-EOH
        global:
          scrape_interval: 30s
          scrape_timeout: 30s
          evaluation_interval: 1m
        
        scrape_configs:
          - job_name: vmagent
            static_configs:
              - targets: ['{{ env "NOMAD_UPSTREAM_ADDR_victoria_metrics" }}']
            relabel_configs:
              - target_label: node
                replacement: '{{ env "attr.unique.hostname" }}'
              - target_label: site
                replacement: '{{ env "meta.node.site" }}'
              - target_label: location
                replacement: '{{ env "meta.node.location" }}'
              - target_label: service
                replacement: 'vmagent'
        
          - job_name: vmagent-envoy
            static_configs:
              - targets: ['127.0.0.1:9001']
            relabel_configs:
              - target_label: node
                replacement: '{{ env "attr.unique.hostname" }}'
              - target_label: site
                replacement: '{{ env "meta.node.site" }}'
              - target_label: location
                replacement: '{{ env "meta.node.location" }}'
        
          - job_name: nomad
            scheme: https
            consul_sd_configs:
              - server: '100.79.63.127:8501'
                token: '{{ env "CONSUL_TOKEN" }}'
                scheme: https
                services: [ nomad-client, nomad ]
            relabel_configs:
              - source_labels: [ __meta_consul_metadata_site ]
                action: keep
                regex: '{{ env "meta.node.site" }}'
              - source_labels: [ __meta_consul_tags ]
                regex: (.*)http(.*)
                action: keep
              - source_labels: [ __meta_consul_node ]
                regex: (.+)
                target_label: node
              - source_labels: [ __meta_consul_metadata_site ]
                regex: (.*)
                target_label: site
              - source_labels: [ __meta_consul_metadata_location ]
                regex: (.*)
                target_label: location
            metrics_path: /v1/metrics
            params:
              format: [ prometheus ]
        
          - job_name: dynamic-services
            consul_sd_configs:
              - server: '100.79.63.127:8501'
                token: '{{ env "CONSUL_TOKEN" }}'
                scheme: https
            relabel_configs:
              - source_labels: [ __meta_consul_metadata_site ]
                action: keep
                regex: '{{ env "meta.node.site" }}'
              - source_labels: [ __meta_consul_service ]
                action: drop
                regex: (.+)-sidecar-proxy
              - source_labels: [ __meta_consul_service_metadata_metrics_port ]
                action: keep
                regex: (.+)
              - source_labels: [ __meta_consul_address, __meta_consul_service_metadata_metrics_port ]
                regex: ([^:]+)(?::\d+)?;(\d+)
                replacement: '$${1}:$${2}'
                target_label: __address__
              - source_labels: [ __meta_consul_service_metadata_metrics_path ]
                regex: (.+)
                target_label: __metrics_path__
              - source_labels: [ __meta_consul_service ]
                regex: (.*)
                target_label: service
              - source_labels: [ __meta_consul_node ]
                regex: (.*)
                target_label: node
              - source_labels: [ __meta_consul_metadata_site ]
                regex: (.*)
                target_label: site
              - source_labels: [ __meta_consul_metadata_location ]
                regex: (.*)
                target_label: location
            params:
              format: [ prometheus ]
        
          - job_name: envoy-services
            consul_sd_configs:
              - server: '100.79.63.127:8501'
                token: '{{ env "CONSUL_TOKEN" }}'
                scheme: https
            relabel_configs:
              - source_labels: [ __meta_consul_metadata_site ]
                action: keep
                regex: '{{ env "meta.node.site" }}'
              - source_labels: [ __meta_consul_service ]
                action: drop
                regex: (.+)-sidecar-proxy
              - source_labels: [ __meta_consul_service_metadata_envoy_port ]
                action: keep
                regex: (.+)
              - source_labels: [ __meta_consul_address, __meta_consul_service_metadata_envoy_port ]
                regex: ([^:]+)(?::\d+)?;(\d+)
                replacement: '$${1}:$${2}'
                target_label: __address__
              - source_labels: [ __meta_consul_service_metadata_envoy_path ]
                regex: (.+)
                target_label: __metrics_path__
              - source_labels: [ __meta_consul_node ]
                regex: (.*)
                target_label: node
              - source_labels: [ __meta_consul_metadata_site ]
                regex: (.*)
                target_label: site
              - source_labels: [ __meta_consul_metadata_location ]
                regex: (.*)
                target_label: location
            params:
              format: [ prometheus ]
        
          - job_name: traefik
            consul_sd_configs:
              - server: '100.79.63.127:8501'
                token: '{{ env "CONSUL_TOKEN" }}'
                scheme: https
                services: [ traefik ]
            relabel_configs:
              - source_labels: [ __meta_consul_metadata_site ]
                action: keep
                regex: '{{ env "meta.node.site" }}'
              - source_labels: [ __meta_consul_node ]
                regex: (.*)
                target_label: node
              - source_labels: [ __meta_consul_metadata_site ]
                regex: (.*)
                target_label: site
              - source_labels: [ __meta_consul_metadata_location ]
                regex: (.*)
                target_label: location
                        
          #- job_name: truenas
          #  static_configs:
          #    - targets: [ '100.121.31.8:6999' ]
          #  relabel_configs:
          #    - target_label: node
          #      replacement: 'truenas'
          #    - target_label: site
          #      replacement: 'wantia'
          #    - target_label: location
          #      replacement: 'onprem'
          #    - target_label: service
          #      replacement: 'truenas'
          #  metrics_path: '/api/v1/allmetrics'
          #  params:
          #    format: [ prometheus_all_hosts ]
          #  honor_labels: true
        EOH
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
        memory = 248
      }
    }

    ephemeral_disk {
      size    = 150
    }
  }
}