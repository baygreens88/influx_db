ui = true

# Persistent storage (single node)
storage "file" {
  path = "/vault/data"
}

# Listener (HTTP for local dev/testing; for real prod, use TLS)
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

# Helps Vault advertise its address correctly (esp. with UI/CLI)
api_addr = "http://127.0.0.1:8200"

# In containers, mlock can be tricky; best to disable unless you’ve fully configured it
disable_mlock = true
