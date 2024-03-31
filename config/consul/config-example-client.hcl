data_dir       = "/opt/consul/data"
client_addr    = "0.0.0.0"
# Since we are using tailscale to connect our cluster, we
# intentionally limit all communication to the tailscale network.
bind_addr      = "{{ GetInterfaceIP \"tailscale0\" }}"
advertise_addr = "{{ GetInterfaceIP \"tailscale0\" }}"
node_name      = "<node-name>"
datacenter     = "dc1"
# Generate by using command "consul keygen".
# This key must be the same for all servers and clients.
encrypt        = "<encrypt-key>"
log_level      = "WARN"
# A list of all servers within the tailscale network.
retry_join     = [ "...", "..." ]

tls {
  defaults {
    # Clients only need the root-ca-file, when 'auto_encrypt' is enabled.
    ca_file   = "<root-ca-crt-file>"
    # There still seems to be a problem with my generated
    # self-signed certificate, so these options are required.
    verify_incoming = false
    verify_outgoing = false
  }
  
  internal_rpc {
    verify_server_hostname = true
  }
}

auto_encrypt {
  tls = true
}

addresses {
  # Limit http to localhost only, so that internal connections
  # can still be performed without additional setup.
  http = "127.0.0.1"
}

ports {
  http = 8500
  grpc = 8502
}

connect {
  enabled = true
}

acl {
  enabled                  = true
  default_policy           = "deny"
  enable_token_persistence = true
  tokens {
    # consul acl token create -description "<node-name> agent token" -node-identity "<node-name>:dc1"
    agent  = "<consul-token>"
  }
}

telemetry {
  prometheus_retention_time = "480h"
  disable_hostname          = true
}

node_meta {
  owner    = "<name-the-owner>"
  site     = "<name-your-site>"
  # I differentiate between 'cloud' or 'onprem'
  location = "cloud"
}
