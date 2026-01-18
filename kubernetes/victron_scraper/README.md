Victron scraper with Vault Agent sidecar

This deployment runs the victron scraper with a Vault Agent sidecar that
renders `/out/victron.env` for the scraper to source.

Files:
- `kubernetes/victron-scraper.yaml`

Vault requirements:
- Kubernetes auth enabled and configured.
- Vault role `victron-scraper` bound to the `victron-scraper` service account in `default`.
- Secret path: `kv/data/victron/hemlock` with a `token` field.

Example Vault policy:
```
path "kv/data/victron/*" {
  capabilities = ["read"]
}
```

Example role setup:
```
vault policy write victron-scraper - <<EOF
path "secret/data/victron/*" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/victron-scraper \
  bound_service_account_names=victron-scraper \
  bound_service_account_namespaces=default \
  policies=victron-scraper \
  ttl=1h
```
