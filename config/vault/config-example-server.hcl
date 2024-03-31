disable_mlock = true
# This should be set to the tailscale-address defined for this server.
api_addr      = "https://xxx.xxx.xxx.xxx:8201"
# Since I only run a single instance, cluster traffic is limited to localhost.
cluster_addr  = "https://127.0.0.1:8201"
ui            = true

listener "tcp" {
  # This should be set to the tailscale-address defined for this server.
  address         = "xxx.xxx.xxx.xxx:8201"
  # Since I only run a single instance, cluster traffic is limited to localhost.
  cluster_address = "127.0.0.1:8201"
  tls_disable     = "false"
  tls_cert_file   = "<vault-crt-file>"
  tls_key_file    = "<vault-key-file>"
}

storage "consul" {
  address = "127.0.0.1:8500"
  path    = "services/vault/"
  # consul acl token create -description "Vault Service Token" -service-identity "vault"
  # The token uses the policy 'policy-vault-service'.
  token   = "<consul-token>"
}