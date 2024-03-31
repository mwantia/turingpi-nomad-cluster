job "csi-migration" {
  datacenters = [ "*" ]
  type        = "batch"

  namespace = "*"
  node_pool = "all"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  group "servers" {    

    volume "source" {
      type            = "csi"
      read_only       = true
      source          = "<source-csi-volume>"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    volume "destination" {
      type            = "csi"
      read_only       = false
      source          = "<destination-csi-volume>"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    task "script" {
      driver = "docker"

      volume_mount {
        volume      = "source"
        destination = "/source"
        read_only   = true
      }

      volume_mount {
        volume      = "destination"
        destination = "/destination"
        read_only   = false
      }

      config {
        image   = "busybox:1"
        command = "/bin/sh"
        args    = [ "-c", "cp -pr /source/* /destination" ]
      }
      
      resources {
        cpu    = 256
        memory = 512
      }
    }

    ephemeral_disk {
      size = 150
    }
  }
}