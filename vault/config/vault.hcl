ui = true
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
  unauthenticated_metrics_access = true
}

# Persistent storage (single node)
storage "file" {
  path = "/vault/data"
}

# TLS listener
listener "tcp" {
  address       = "0.0.0.0:4317"
  tls_cert_file = "/vault/config/certs/vault.crt"
  tls_key_file  = "/vault/config/certs/vault.key"
  telemetry {
    unauthenticated_metrics_access = true
  }
}

# Helps Vault advertise its address correctly (esp. with UI/CLI)
api_addr = "https://vault:4317"

# In containers, mlock can be tricky; best to disable unless you’ve fully configured it
disable_mlock = true
