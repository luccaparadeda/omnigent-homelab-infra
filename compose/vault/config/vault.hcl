ui = false
disable_mlock = false

storage "raft" {
  path    = "/vault/file"
  node_id = "vault-1"
}

listener "tcp" {
  address                  = "0.0.0.0:8200"
  cluster_address          = "0.0.0.0:8201"
  tls_disable              = false
  tls_cert_file            = "/vault/tls/server.crt"
  tls_key_file             = "/vault/tls/server.key"
  tls_client_ca_file       = "/vault/tls/ca.crt"
  tls_min_version          = "tls13"
  tls_disable_client_certs = true
}

# Required values are supplied through VAULT_OCIKMS_* environment variables.
# Authentication defaults to the OCI instance principal.
seal "ocikms" {}

telemetry {
  disable_hostname = true
}
