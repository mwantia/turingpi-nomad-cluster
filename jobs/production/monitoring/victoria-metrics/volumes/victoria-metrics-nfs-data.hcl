id   = "victoria-metrics-nfs-data"
name = "victoria-metrics-nfs-data"

namespace = "production"
plugin_id = "truenas-nfs"
type      = "csi"

capacity_min = "10GiB"
capacity_max = "20GiB"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type = "nfs"
}