pid_file = "/tmp/vault-agent.pid"

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/vault/creds/role_id"
      secret_id_file_path = "/vault/creds/secret_id"
    }
  }

  sink "file" {
    config = {
      path = "/vault/token/vault-token"
    }
  }
}

template {
  source      = "/vault/templates/victron.env.tmpl"
  destination = "/out/victron.env"
  perms       = "0640"
}
