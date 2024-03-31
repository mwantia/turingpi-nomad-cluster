job "hello-world" {
  datacenters = ["*"]
  
  namespace = "development"
  node_pool = "turing-rk1"

  group "servers" {
    network {
      mode = "bridge"

      port "envoy" { }
    }

    service {
      name = "hello-world"
      tags = [ "traefik.enable=true", "traefik.location=production" ]
      port = 8085
      
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
    }
    
    ephemeral_disk {
      size = 150
    }

    task "service" {
      driver = "docker"

      config {
        image   = "busybox:1"
        command = "httpd"
        args    = ["-v", "-f", "-p", "8085", "-h", "/local"]
      }
      
      identity {
        env = true
      }
      
      vault { }

      template {
        destination = "local/index.html"
        change_mode = "noop"
        data        = <<-EOF
        <h1>Hello, Nomad!</h1>
        <ul>
          <li>Task: {{env "NOMAD_TASK_NAME"}}</li>
          <li>Group: {{env "NOMAD_GROUP_NAME"}}</li>
          <li>Job: {{env "NOMAD_JOB_NAME"}}</li>
          <li>Metadata value for foo: {{env "NOMAD_META_foo"}}</li>
          {{- with secret "credentials/development/job/hello-world" }}
          <li>Vault value for foo: {{- .Data.data.foo -}}</li>
          {{ end -}}
        </ul>
        EOF
      }

      resources {
        cpu    = 64
        memory = 128
      }
    }
  }
  
  group "gateway" {
    network {
      mode = "bridge"

      port "envoy" { }

      port "inbound" {
        static       = 8085
        to           = 8085
        host_network = "keepalived"
      }
    }

    service {
      name = "hello-world-gateway"
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
              port = 8085

              service {
                name = "hello-world"
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