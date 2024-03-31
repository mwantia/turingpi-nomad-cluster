path "credentials/data/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_namespace}}/truenas/*" {
  capabilities = ["read"]
}
  
path "credentials/metadata/{{identity.entity.aliases.auth_jwt_af6408d3.metadata.nomad_namespace}}/*" {
  capabilities = ["list"]
}
  
path "credentials/metadata/*" {
  capabilities = ["list"]
}