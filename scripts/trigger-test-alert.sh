#!/usr/bin/env bash
set -euo pipefail

PUSHGATEWAY_URL=${PUSHGATEWAY_URL:-http://localhost:9091}
JOB=${JOB:-manual_test_alert}

usage() {
  echo "Usage: $0 [trigger|clear]" >&2
  exit 1
}

action=${1:-}
case "$action" in
  trigger)
    printf 'manual_test_alert 1\n' | curl -sS --data-binary @- "$PUSHGATEWAY_URL/metrics/job/$JOB" >/dev/null
    echo "Triggered manual test alert (job=$JOB)"
    ;;
  clear)
    curl -sS -X DELETE "$PUSHGATEWAY_URL/metrics/job/$JOB" >/dev/null
    echo "Cleared manual test alert (job=$JOB)"
    ;;
  *)
    usage
    ;;
esac
