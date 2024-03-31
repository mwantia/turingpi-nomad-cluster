path "credentials/data/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_namespace}}/job/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_job_id}}/*" {
  capabilities = ["read"]
}

path "credentials/data/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_namespace}}/job/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_job_id}}" {
  capabilities = ["read"]
}
  
path "credentials/metadata/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_namespace}}/*" {
  capabilities = ["list"]
}
  
path "credentials/metadata/*" {
  capabilities = ["list"]
}

path "certificates/data/*" {
  capabilities = ["read"]
}

path "certificates/metadata/*" {
  capabilities = ["list"]
}

path "cache/data/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_namespace}}/*" {
  capabilities = ["read", "create", "update"]
}

path "cache/metadata/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_namespace}}/*" {
  capabilities = ["list"]
}

path "cache/metadata/*" {
  capabilities = ["list"]
}