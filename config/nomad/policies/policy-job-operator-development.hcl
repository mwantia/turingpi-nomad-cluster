namespace "default" {
  policy = "deny"
  capabilities = []
}

namespace "development" {
  policy = "write"
  capabilities = []
  
  variables {
    path "*" {
      capabilities = ["write", "read", "destroy", "list"]
    }
  }
}

namespace "production" {
  policy = "deny"
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

host_volume "dev-*" {
  policy = "write"
}

operator {
  policy = "write"
}

agent {
  policy = "write"
}