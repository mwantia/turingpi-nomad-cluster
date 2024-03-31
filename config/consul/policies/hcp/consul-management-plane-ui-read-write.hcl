
acl      = "write"
keyring  = "write"
operator = "write"
mesh     = "write"
peering  = "write"

agent_prefix "" {
	policy = "write"
}

event_prefix "" {
  policy = "write"
}

identity_prefix "" {
  policy     = "write"
  intentions = "write"
}

key_prefix "" {
  policy = "write"
}

node_prefix "" {
  policy = "write"
}

query_prefix "" {
  policy     = "write"
  intentions = "write"
}

service_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}

partition_prefix "" {
	mesh    = "read"
	peering = "read"

	namespace "default" {
		node_prefix "" {
			policy = "read"
		}

		agent_prefix "" {
			policy = "read"
		}
	}
}

namespace_prefix "" {
  acl = "read"

  key_prefix "" {
    policy = "read"
  }

  node_prefix "" {
    policy = "read"
  }

  session_prefix "" {
    policy = "read"
  }

  service_prefix "" {
    policy     = "write"
    intentions = "read"
  }
}