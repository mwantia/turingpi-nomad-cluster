id   = "qdrant-nfs-data"
name = "qdrant-nfs-data"

namespace = "production"
plugin_id = "truenas-nfs"
type      = "csi"

capacity_min = "1GiB"
capacity_max = "5GiB"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type = "nfs"
}