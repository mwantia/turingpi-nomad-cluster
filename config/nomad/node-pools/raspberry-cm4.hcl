node_pool "raspberry-cm4" {
  description = "Nomad Nodes running on Raspberry CM4 Modules."

  meta { 
    location = "onprem"
    roles    = "database,worker"
  }
}
