#!/usr/bin/env bash
# Terraform Drift Detection -- runs daily via cron
# Detects manual changes vs IaC definitions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
REPORT="/tmp/tf-drift-$(date +%Y%m%d).txt"

{
  echo "=== Terraform Drift Detection ==="
  echo "Date: $(date)"
  echo ""

  for env in aws gcp; do
    echo "--- Environment: $env ---"
    cd "$REPO_DIR/terraform/$env"
    for component in vpc eks ecr; do
      [ -d "$component" ] || continue
      echo "  Checking: $component..."
      cd "$component"
      if terragrunt plan -detailed-exitcode 2>&1; then
        echo "  PASS: No drift"
      elif [ $? -eq 2 ]; then
        echo "  WARNING: DRIFT DETECTED!"
      fi
      cd ..
    done
    echo ""
  done
  echo "=== End ==="
} | tee "$REPORT"

# Alert if drift found
if grep -q "DRIFT DETECTED" "$REPORT"; then
  echo "Drift detected! Sending alert..."
  # curl -X POST -H 'Content-type: application/json' \
  #   --data "{\"text\":\"$(head -50 $REPORT)\"}" "$SLACK_WEBHOOK_URL"
fi