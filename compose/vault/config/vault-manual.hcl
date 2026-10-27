ui = false
# The host is asserted to have no active swap before this profile is started.
# Disabling mlock avoids a restart loop on constrained OCI E2 Micro guests,
# where the container cannot raise the host's locked-memory allocation.
disable_mlock = true

storage "raft" {
  path    = "/vault/file"
  node_id = "vault-1"
}
# This listener is published only on the host's Tailscale address. WireGuard
# supplies encrypted transport between the two Oracle nodes.
listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = true
}

telemetry {
  disable_hostname = true
}
