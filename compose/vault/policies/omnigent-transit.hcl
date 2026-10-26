path "transit/encrypt/omnigent-credentials" {
  capabilities = ["update"]
}

path "transit/decrypt/omnigent-credentials" {
  capabilities = ["update"]
}

path "transit/keys/omnigent-credentials" {
  capabilities = ["read"]
}

path "sys/health" {
  capabilities = ["read"]
}
