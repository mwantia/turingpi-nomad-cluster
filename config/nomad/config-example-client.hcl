data_dir   = "/srv/nomad/data"
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
  address = "https://vault.service.consul:8201"

  default_identity {
    aud = ["vault.io"]
    ttl = "1h"
  }
}

client {
  enabled   = true
  # See config for 'node-pools', or omit if not used/required.
  # Create by using command 'nomad node pool apply <node-pool-config>'.
  node_pool = "<node-pool-name>"

  artifact {
    disable_filesystem_isolation = false
  }
  # Since we are using tailscale to connect our cluster, we
  # intentionally limit all communication to the tailscale network.
  network_interface = "tailscale0"
  network_speed     = 1000

  host_network "tailscale" {
    interface      = "tailscale0"
    reserved_ports = "22"
  }
  # Important! Per default all containers created by nomad will use
  # the network 'tailscale'. If a container should be accessable over
  # a different network, it must be defined here first and can then 
  # be selected within the job-definition when deploying.
  host_network "private" {
    # In most cases the interface will be eth0.
    interface      = "<internal-network-interface>"
    cidr           = "<internal-cidr>"
    reserved_ports = "22"
  }
  # See 'keepalived' or other solutions for creating a floating ip.
  host_network "keepalived" {
    # In most cases the interface will be eth0.
    interface      = "<keepalived-network-interface>"
    cidr           = "<keepalived-address>/32"
    reserved_ports = "22"
  }

  meta {
    # The original image doesn't support arm64 (as of writing).
    connect.gateway_image = "mwantia/envoy:arm64"
    connect.sidecar_image = "mwantia/envoy:arm64"

    node.site     = "<name-your-site>"
    # Since I plan to use multiple boards I want to diferentiate 
    # between them by using 'tp1', 'tp2', 'tpN' when deploying jobs.
    node.board    = "<name-the-board>"
    # I differentiate between 'cloud' or 'onprem'.
    node.location = "<name-the-location>"
    # I tried to separate nodes by giving them roles, so that I can
    # fine-grain job-deployments using constraints and affinities.
    node.roles    = "worker,database"
  }

  host_volume "docker-sock" {
    path      = "/var/run/docker.sock"
    read_only = false
  }
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

plugin "docker" {
  config {
    volumes {
      enabled      = true
      selinuxlabel = "z"
    }

    extra_labels = ["job_name", "task_group_name", "task_name", "node_name"]
    allow_privileged = true
  }
}