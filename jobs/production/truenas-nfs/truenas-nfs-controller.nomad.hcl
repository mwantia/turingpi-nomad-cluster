job "truenas-nfs-controller" {
  datacenters = [ "*" ]
  region      = "global"

  namespace   = "production"
  node_pool   = "all"
  
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  constraint {
    attribute = "${meta.node.location}"
    value     = "onprem"
  }

  group "controller" {
    count = 1

    network {
      mode = "bridge"

      port "grpc" {
        to     = 9000
        static = 9000
      }
    }

    ephemeral_disk {
      size = 150
    }

    task "plugin" {
      driver = "docker"

      csi_plugin {
        id        = "truenas-nfs"
        type      = "controller"
        mount_dir = "/csi"
      }

      config {
        image      = "democraticcsi/democratic-csi:v1.9.0"
        ports      = [ "grpc" ]
        privileged = true
        args       = [ 
          "--csi-version=1.5.0",
          "--csi-name=truenas-nfs",
          "--driver-config-file=/secrets/driver-config-file.yaml",
          "--log-level=debug",
          "--csi-mode=controller",
          "--server-socket=/csi/csi.sock",
          "--server-address=0.0.0.0",
          "--server-port=9000"
        ]

        mount {
          type     = "bind"
          source   = "/"
          target   = "/host"
          readonly = false
        }
      }

      template {
        data        = <<-EOH
        {{- range service "truenas" }}
        driver: freenas-api-nfs
        instance_id:
        nfs:
          shareHost: '{{- .Address -}}'
          shareAlldirs: false
          shareAllowedHosts: []
          shareAllowedNetworks: []
          shareMaprootUser: root
          shareMaprootGroup: root
          shareMapallUser: ''
          shareMapallGroup: ''
        httpConnection:
          protocol: http
          host: '{{- .Address -}}'
          port: 80
        {{ end -}}{{- with secret "credentials/production/truenas/csi-plugins" }}
          apiVersion: 2
          apiKey: '{{ .Data.data.apikey }}'
          allowInsecure: true
        zfs:
          datasetParentName: '{{ .Data.data.dataset }}'
          detachedSnapshotsDatasetParentName: '{{ .Data.data.snapshots }}'
          datasetEnableQuotas: true
          zvolEnableReservation: false
          datasetPermissionsMode: '0777'
          datasetPermissionsUser: 0
          datasetPermissionsGroup: 0
        {{ end -}}
        EOH
        change_mode = "restart"
        destination = "secrets/driver-config-file.yaml"
      }

      identity {
        env = true
      }
      
      vault {
        role = "truenas-plugins"
      }

      consul { }

      resources {
        cpu    = 64
        memory = 128
      }
    }
  }
}