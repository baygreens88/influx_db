External Secrets (Vault) setup for Telegraf

This folder contains the Kubernetes resources to sync Vault secrets into
Kubernetes Secrets using External Secrets Operator (ESO) with Vault Kubernetes
auth. It does not install the operator itself.

Install ESO (once):
- This repo includes a patched installer at `kubernetes/external-secrets/external-secrets.yaml`
  that deploys ESO into the `external-secrets` namespace.
  - Apply with: `kubectl apply -f kubernetes/external-secrets/external-secrets.yaml`
  - It adjusts the webhook/cert controller args for the `external-secrets` namespace.

Vault side (example):
1) Create a token reviewer service account for ESO:
   - `kubectl create serviceaccount vault-auth -n external-secrets`
   - `kubectl create clusterrolebinding vault-auth-delegator --clusterrole=system:auth-delegator --serviceaccount=external-secrets:vault-auth`
2) Configure Vault Kubernetes auth from the Vault pod (replace VAULT_TOKEN):
   ```sh
   jwt=$(kubectl -n external-secrets create token vault-auth)
   VAULT_POD=$(kubectl get pods -l app=vault -o jsonpath='{.items[0].metadata.name}')
   kubectl exec "$VAULT_POD" -- sh -c '
     export VAULT_ADDR=https://vault:4981
     export VAULT_CACERT=/vault/config/certs/vault.crt
     export VAULT_TOKEN=REPLACE_WITH_ROOT_TOKEN
     vault auth enable kubernetes || true
     vault write auth/kubernetes/config \
       token_reviewer_jwt="'"$jwt"'" \
       kubernetes_host="https://kubernetes.default.svc" \
       kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
     vault policy write telegraf - <<EOF
   path "secret/data/telegraf/*" {
     capabilities = ["read"]
   }
   EOF
     vault write auth/kubernetes/role/telegraf \
       bound_service_account_names=telegraf \
       bound_service_account_namespaces=default \
       policies=telegraf \
       ttl=1h
     vault kv put secret/telegraf/mqtt username=YOUR_USER password=YOUR_PASS
   '
   ```

Kubernetes side:
- Create the Vault CA secret (if using the self-signed cert):
  - `kubectl create secret generic vault-ca --from-file=vault.crt=kubernetes/vault/config/certs/vault.crt`
- Apply the ServiceAccount, SecretStore, and ExternalSecret manifests in this folder.
 - `kubectl apply -f kubernetes/external-secrets/telegraf-serviceaccount.yaml`
 - `kubectl apply -f kubernetes/external-secrets/secretstore.yaml`
 - `kubectl apply -f kubernetes/external-secrets/externalsecret-telegraf.yaml`
- The ExternalSecret will create a Kubernetes Secret named `telegraf-mqtt`
  containing `username` and `password`.

Files:
- `telegraf-serviceaccount.yaml` (ServiceAccount used for Vault auth)
- `secretstore.yaml` (Vault connection + auth)
- `externalsecret-telegraf.yaml` (syncs MQTT creds into K8s Secret)
- `vault-policy-telegraf.hcl` (example Vault policy)
