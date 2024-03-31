service "vault" { 
  policy = "write" 
}

key_prefix "services/vault/" { 
  policy = "write" 
}

agent_prefix "" { 
  policy = "read" 
}

session_prefix "" { 
  policy = "write" 
}
