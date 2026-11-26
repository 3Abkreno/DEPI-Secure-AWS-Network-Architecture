#!/usr/bin/env bash
# Destroys every paid stack in reverse order.
# Leaves 10-network (free) and 00-bootstrap (state bucket) in place.
set -euo pipefail
cd "$(dirname "$0")/.."
for s in 70-inspection 60-monitoring 50-edge 40-hybrid 30-transit 20-prod-app; do
  if [ -d "stacks/$s/.terraform" ]; then
    echo "== destroying $s"
    terraform -chdir="stacks/$s" destroy -auto-approve
  fi
done
echo "Done. Now run scripts/check-running.sh"
