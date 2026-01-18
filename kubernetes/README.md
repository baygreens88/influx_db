Kubernetes manifests and host proxies

This folder holds Kubernetes manifests plus host-level proxy helpers used to
expose select services on a macOS host when Docker Desktop NodePort/hostPort
is not reachable from other devices on the LAN.

LaunchAgent proxy files:

- Combined proxy: `kubernetes/proxies/proxies.plist`
  - Runs `kubernetes/proxies/start-proxies.sh`.
  - Forwards:
    - `:8500` → `127.0.0.1:30850` (Consul UI)
    - `:4981` → `127.0.0.1:30881` (Vault HTTPS)
    - `:9090` → `127.0.0.1:30900` (Prometheus UI)
    - `:9091` → `127.0.0.1:30901` (Pushgateway)
    - `:9093` → `127.0.0.1:30903` (Alertmanager)
    - `:3000` → `127.0.0.1:30300` (Grafana UI)
    - `:8883` → `127.0.0.1:30883` (MQTT TLS)
  - Needed so Wi-Fi clients can reach these services on the Mac host.
