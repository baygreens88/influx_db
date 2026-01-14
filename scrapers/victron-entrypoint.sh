#!/bin/sh
set -eu

if [ -f /out/victron.env ]; then
  set -a
  # shellcheck disable=SC1091
  . /out/victron.env
  set +a
fi

if [ "${VICTRON_API_KEY:-}" = "" ]; then
  i=0
  while [ "$i" -lt 30 ] && [ ! -s /out/victron.env ]; do
    i=$((i + 1))
    sleep 1
  done

  if [ -s /out/victron.env ]; then
    set -a
    # shellcheck disable=SC1091
    . /out/victron.env
    set +a
  fi
fi

while true; do
  ruby /app/scrapers/victron.rb "$@" || true
  sleep 300
done
