#!/usr/bin/env bash
# Runs a playbook through ./lab and, if it fails, publishes the failing tasks
# as a GitHub annotation so the error shows on the run summary page.
# Usage: .github/scripts/run-playbook.sh <playbook> <logfile> [ansible-playbook args]
set -uo pipefail

playbook="$1"; log="$2"; shift 2

./lab run "$playbook" "$@" 2>&1 | tee "$log"
rc=${PIPESTATUS[0]}

if [[ $rc -ne 0 ]]; then
  # Each failing task header plus the error lines under it, capped for the annotation size limit
  details=$(grep -E -B2 -A12 '^(fatal|failed):' "$log" | head -c 3500)
  [[ -z "$details" ]] && details=$(tail -n 40 "$log" | head -c 3500)
  details=${details//'%'/'%25'}
  details=${details//$'\r'/'%0D'}
  details=${details//$'\n'/'%0A'}
  echo "::error title=${playbook} failed (rc=${rc})::${details}"
fi

exit "$rc"
