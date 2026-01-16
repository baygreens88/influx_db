ui = true

# Persistent storage (single node)
storage "file" {
  path = "/vault/data"
}

# TLS listener
listener "tcp" {
  address       = "0.0.0.0:8201"
  tls_cert_file = "/vault/config/certs/vault.crt"
  tls_key_file  = "/vault/config/certs/vault.key"
}

# Helps Vault advertise its address correctly (esp. with UI/CLI)
api_addr = "https://vault:8201"

# In containers, mlock can be tricky; best to disable unless you’ve fully configured it
disable_mlock = true
