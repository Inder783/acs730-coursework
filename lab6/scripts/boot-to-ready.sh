#!/usr/bin/env bash
# boot-to-ready.sh <label> <host> <start-epoch>
set -euo pipefail
label=${1:?usage: boot-to-ready.sh <label> <host> <start-epoch>}
host=${2:?usage: boot-to-ready.sh <label> <host> <start-epoch>}
start=${3:?usage: boot-to-ready.sh <label> <host> <start-epoch>}
timeout_seconds=${BOOT_READY_TIMEOUT:-900}
while ! curl -fsS -m 2 "http://${host}/" >/dev/null 2>&1; do
  if (( $(date +%s) - start >= timeout_seconds )); then
    echo "Timed out waiting for HTTP readiness: ${label}" >&2
    exit 1
  fi
  sleep 2
done
echo "${label}: $(( $(date +%s) - start )) seconds"
