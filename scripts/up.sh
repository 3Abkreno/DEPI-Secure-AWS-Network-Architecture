#!/usr/bin/env bash
# Usage: scripts/up.sh 20-prod-app 30-transit
# Applies the given stacks in the order given. Every hour these run costs credit.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then
  echo "usage: scripts/up.sh <stack> [<stack> ...]" >&2
  exit 1
fi
for s in "$@"; do
  echo "== applying $s"
  terraform -chdir="stacks/$s" init -input=false
  terraform -chdir="stacks/$s" apply -auto-approve
done
echo "Started at $(date). Log this session in docs/hours.md and run scripts/down.sh when done."
