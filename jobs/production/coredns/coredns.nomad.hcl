job "coredns" {
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
    attribute = "${meta.node.keepalived}"
    value     = "true"
  }

  group "servers" {
    network {
      mode = "bridge"

      port "metrics" { }
      port "envoy" { }

      port "health" {
        to = 8080
      }

      port "dns" {
        to           = 53
        static       = 53
        host_network = "keepalived"
      }
    }

    service {
      name = "coredns"
      port = 53

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
                local_path_port = 9253
                listener_port   = "metrics"
              }
            }

            upstreams {
              destination_name = "redis-db0"
              local_bind_port  = 6379
            }

            config {
              envoy_prometheus_bind_addr = "0.0.0.0:${NOMAD_HOST_PORT_envoy}"
            }
          }
        }
      }

      check {
        expose   = true
        port     = "health"
        type     = "http"
        name     = "health"
        path     = "/health"
        interval = "30s"
        timeout  = "2s"
      }
    }

    task "service" {
      driver = "docker"
      user   = "root"

      config {
        image      = "mwantia/coredns-guard:${attr.cpu.arch}"
        privileged = true

        mount {
          type = "bind"
          target = "/coredns/Corefile"
          source = "local/Corefile"
          readonly = true

          bind_options {
            propagation = "rshared"
          }
        }
      }

      template {
        destination = "local/Corefile"
        change_mode = "restart"
        data        = <<-EOH
        (default) {
          metadata
          log
          errors
        }
        
        (debugging) {
          debug
        }
                
        (rcache) {
          cache 60
          redisc 600 {
            endpoint 127.0.0.1:6379
          }
        }
        
        (metrics) {
          prometheus :9253
        }
        
        (global) {
          health :8080
        }
        
        {{- $defaultTtl  := "60" -}}
        {{- $defaultType := "A" -}}
        {{- $defaultAddress := "127.0.0.1" -}}
        
        {{- range $zone, $v := tree "dns/zones" | byKey }}
        {{ $zone }} {        
          {{- if keyExists (print "dns/zones/" $zone "/config") }}
          {{- with $configJson := key (print "dns/zones/" $zone "/config") | parseJSON }}{{ range $i := $configJson.imports }}
          import {{ $i }}
          {{- end }}
                
          records {
            {{- range $record := ls (print "dns/zones/" $zone "/records") }}
            {{- $recordJson := parseJSON $record.Value }}
            {{ $record.Key }}
            {{- if $recordJson.ttl }} {{ $recordJson.ttl }} {{- else }} {{ $defaultTtl }} {{ end }} IN  
            {{- if $recordJson.type }}  {{ $recordJson.type }}  {{- else }} {{ $defaultType }}  {{- end }}
            {{- if $recordJson.address }} {{ $recordJson.address }} {{- else }}  {{ $defaultAddress }}  {{- end }}
            {{- end }}
          }
                
          {{- if $configJson.forwarders }}
          forward .{{ range $f := $configJson.forwarders }} {{ $f }}{{- end }}
          {{- end }}{{- end }}
          {{- end }}
        }
        {{ end -}}
        
        consul {
          import metrics
          forward . 100.79.63.127:8600
        }
                
        {{- if keyExists (print "dns/config") }}
        . {
          {{- with $globalConfigJson := key "dns/config" | parseJSON }}
                
          {{- range $i := $globalConfigJson.imports }}
          import {{ $i }}
          {{- end }}
        
          {{- if $globalConfigJson.filters }}
          guard {
            {{- range $f := $globalConfigJson.filters }}
            {{- if $f.url }}
            url {{ $f.url }} {{ $f.type }} {{ $f.refresh }}
            {{- end }}{{- if $f.file }}
            file {{ $f.url }} {{ $f.type }} {{ $f.refresh }}
            {{- end }}{{- if $f.directory }}
            directory {{ $f.url }} {{ $f.type }} {{ $f.refresh }}
            {{- end }}
            {{- end }}
          }
          {{- end }}
                
          {{- if $globalConfigJson.forwarders }}
          forward .{{ range $f := $globalConfigJson.forwarders }} {{ $f }}{{- end }}
          {{- end }}{{- end }}
        }
        {{- end }}
        EOH
      }

      consul {

      }
      
      resources {
        cpu    = 128
        memory = 128
      }
    }

    ephemeral_disk {
      size = 150
    }
  }
}