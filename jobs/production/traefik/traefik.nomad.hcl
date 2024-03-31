job "traefik" {
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

      port "admin" { 
        to     = 8080
        static = 8080
      }

      port "web" {
        to           = 80
        static       = 80
        host_network = "keepalived"
      }

      port "websecure" {
        to           = 443
        static       = 443
        host_network = "keepalived"
      }
    }

    service {
      name = "traefik"
      port = "admin"

      meta {
        envoy_port = "${NOMAD_HOST_PORT_admin}"
        envoy_path = "/metrics"

        health_port = "${NOMAD_HOST_PORT_admin}"
        health_path = "/ping"
      }

      connect {
        native = true
      }

      check {
        type     = "http"
        name     = "health"
        path     = "/ping"
        interval = "30s"
        timeout  = "2s"
      }
    }

    ephemeral_disk {
      size    = 150
      sticky  = true
      migrate = true
    }

    task "service" {
      driver = "docker"

      config {
        image = "traefik:v3.0"
        args  = ["--configFile=/secrets/traefik.yaml"]
      }

      template {
        data        = <<-EOH
        TZ = "EUROPE/BERLIN"
        LEGO_DISABLE_CNAME_SUPPORT = "true"
        {{- with secret "credentials/production/job/traefik/cloudflare" }}
        CF_API_EMAIL = "{{ .Data.data.api_email }}"
        CF_API_KEY = "{{ .Data.data.api_key }}"
        {{ end -}}
        EOH
        destination = "secrets/file.env"
        change_mode = "restart"
        env         = true
      }

      template {
        left_delimiter  = "[["
        right_delimiter = "]]"
        data        = <<-EOH
        entrypoints:
          web:
            address: ':80'
            http:
              redirections:
                entryPoint:
                  to: websecure
                  scheme: https
          websecure:
            address: ':443'
            http:
        #     middlewares:
        #       - 'secure-headers@file'
              tls:
                certResolver: lets-encrypt
                options: default
                domains:
                  - main: 'wantia.app'
                    sans:
                      - '*.wantia.app'
        global:
          sendAnonymousUsage: false
          checkNewVersion: false
        api:
          dashboard: true
          insecure: true
        metrics:
          prometheus:
            addRoutersLabels: true
            addServicesLabels: true
        ping: { }
        log:
          level: INFO
        providers:
          file:
            directory: /local/config
          consulcatalog:
            endpoint:
              address: '100.79.63.127:8501'
              scheme: https
              [[- with secret "credentials/production/job/traefik/consul" ]]
              token: '[[ .Data.data.token ]]'
              [[- end ]]
              tls:
                insecureSkipVerify: true
            connectAware: true
            connectByDefault: true
            exposedByDefault: false
            defaultRule: 'Host(`{{ .Name }}.wantia.app`)'
        certificatesresolvers:
          [[- with secret "credentials/production/job/traefik/cloudflare" ]]
          lets-encrypt:
            acme:         
              email: '[[ .Data.data.api_email ]]'
              storage: /alloc/data/acme.json
              caserver: 'https://acme-staging-v02.api.letsencrypt.org/directory'
              dnschallenge:
                provider: cloudflare
                disablepropagationcheck: true
                delayBeforeCheck: 30
                resolvers:
                  - '1.1.1.1:53'
                  - '8.8.8.8:53'
          lets-encrypt-staging:
            acme:
              email: '[[ .Data.data.api_email ]]'
              storage: /alloc/data/acme-staging.json
              caserver: 'https://acme-staging-v02.api.letsencrypt.org/directory'
              dnschallenge:
                provider: cloudflare
                disablepropagationcheck: true
                delayBeforeCheck: 0
                resolvers:
                  - '1.1.1.1:53'
                  - '8.8.8.8:53'
          [[- end ]]
        EOH
        destination = "secrets/traefik.yaml"
        change_mode = "restart"
      }

      template {
        data        = <<-EOH
        tls:
          options:
            default:
              minVersion: VersionTLS12
              cipherSuites:
                - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
                - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
                - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
                - TLS_AES_128_GCM_SHA256
                - TLS_AES_256_GCM_SHA384
                - TLS_CHACHA20_POLY1305_SHA256
              curvePreferences:\
                - CurveP521
                - CurveP384
              sniStrict: true
              mintls13:
                minVersion: VersionTLS13
        EOH
        destination = "local/config/tls-options-default.yml"
        change_mode = "restart"
      }

      template {
        data        = <<-EOH

        EOH
        destination = "local/config/authelia-forwardauth.yml"
        change_mode = "restart"
      }
      
      identity {
        env = true
      }
      
      vault { }
      
      resources {
        cpu    = 128
        memory = 128
      }
    }
  }
}