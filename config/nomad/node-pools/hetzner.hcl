node_pool "hetzner" {
  description = "Nomad Nodes within the Hetzner Cloud Infrastructure."

  meta {
    location = "cloud"
    roles    = "database,worker,exit"
  }
}
