namespace "default" {
  policy = "deny"
  capabilities = []
}

namespace "production" {
  policy = "write"
  capabilities = []
  
  variables {
    path "*" {
      capabilities = ["write", "read", "destroy", "list"]
    }
  }
}

namespace "development" {
  policy = "read"
  capabilities = ["list-jobs"]
  variables {
    path "*" {
      capabilities = ["list"]
    }
  }
}

host_volume "*" {
  policy = "deny"
}

host_volume "prod-*" {
  policy = "write"
}

operator {
  policy = "write"
}

agent {
  policy = "write"
}