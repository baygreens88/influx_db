path "kv/data/victron/hemlock" {
  capabilities = ["read"]
}

path "kv/data/slack" {
  capabilities = ["read"]
}

path "kv/metadata/victron/*" {
  capabilities = ["list"]
}

path "kv/metadata/slack" {
  capabilities = ["read"]
}
