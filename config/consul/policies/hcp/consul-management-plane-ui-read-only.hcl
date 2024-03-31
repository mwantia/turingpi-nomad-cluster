acl      = "read"
keyring  = "read"
operator = "read"
mesh     = "read"
peering  = "read"

agent_prefix "" {
	policy = "read"
}

event_prefix "" {
  policy = "read"
}

identity_prefix "" {
  policy     = "read"
  intentions = "read"
}

key_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

query_prefix "" {
  policy     = "read"
  intentions = "read"
}

service_prefix "" {
  policy = "read"
}

session_prefix "" {
  policy = "read"
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
    policy     = "read"
    intentions = "read"
  }
}
