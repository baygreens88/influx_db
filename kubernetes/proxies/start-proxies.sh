#!/bin/sh
set -eu

SOCAT_BIN="/opt/homebrew/bin/socat"

if [ ! -x "$SOCAT_BIN" ]; then
  echo "socat not found at $SOCAT_BIN" >&2
  exit 1
fi

start_proxy() {
  listen_port="$1"
  target_port="$2"
  "$SOCAT_BIN" "TCP-LISTEN:${listen_port},fork,reuseaddr" "TCP:127.0.0.1:${target_port}" &
}

# Consul UI
start_proxy 8500 30850

# Vault HTTPS
start_proxy 4981 30881

# Prometheus UI
start_proxy 9090 30900

# Pushgateway
start_proxy 9091 30901

# Alertmanager
start_proxy 9093 30903

# Grafana UI
start_proxy 3000 30300

# Mosquitto MQTT TLS
start_proxy 8883 30883

wait
