id   = "ollama-nfs-data"
name = "ollama-nfs-data"

namespace = "production"
plugin_id = "truenas-nfs"
type      = "csi"

capacity_min = "10GiB"
capacity_max = "50GiB"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type = "nfs"
}