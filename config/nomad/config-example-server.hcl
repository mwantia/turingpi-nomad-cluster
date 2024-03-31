data_dir   = "/opt/nomad/data"
bind_addr  = "0.0.0.0"
datacenter = "dc1"
# Since we are using tailscale to connect our cluster, we
# intentionally limit all communication to the tailscale network.
advertise {
  http = "{{ GetInterfaceIP \"tailscale0\" }}"
  rpc  = "{{ GetInterfaceIP \"tailscale0\" }}"
  serf = "{{ GetInterfaceIP \"tailscale0\" }}"
}

tls {
  http = true
  rpc  = true

  ca_file   = "<root-ca-crt-file>"
  cert_file = "<consul-crt-file>"
  key_file  = "<consul-key-file>"
  # There still seems to be a problem with my generated
  # self-signed certificate, so these options are required.
  verify_server_hostname = false
  verify_https_client    = false
}

consul {
  # consul acl token create -description "<node-name> agent token" -node-identity "<node-name>:dc1"
  # The token uses the policy 'policy-consul-nomad-agents'.
  token            = "<consul-token>"
  auto_advertise   = true
  server_auto_join = true
  client_auto_join = true

  service_identity {
    aud = [ "consul.io" ]
    ttl = "1h"
  }

  task_identity {
    aud = [ "consul.io" ]
    ttl = "1h"
  }
}

vault {
  enabled = true

  default_identity {
    aud = ["vault.io"]
    ttl = "1h"
  }
}

server {
  enabled = true
}

ui {
  enabled = true
}

acl {
  enabled = true
}

telemetry {
  collection_interval        = "5s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}