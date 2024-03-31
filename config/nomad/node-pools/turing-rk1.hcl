node_pool "turing-rk1" {
  description = "Nomad Nodes running on Turing RK1 Computer Modules."

  meta { 
    location = "onprem"
    roles    = "database,worker,perf"
  }
}
