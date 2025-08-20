#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
LOGDIR="$repo_root/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/run-$(date +%Y%m%d-%H%M%S).log"
{
  echo "[INFO] Starting full PR-DR run at $(date)"
  PROJECT_ID=$(gcloud config get-value project)
  export TF_VAR_project_id="$PROJECT_ID"
  echo "[INFO] Using GCP project: $PROJECT_ID"

  echo "[INFO] Terraform init/apply..."
  cd "$repo_root/terraform"
  terraform init -input=false -upgrade -backend=false
  terraform apply -auto-approve

  echo "[INFO] Terraform apply completed at $(date)"
  echo "[INFO] Verifying clusters are reachable..."
  for CFG in "$repo_root/terraform/kubeconfigs/pr.yaml" "$repo_root/terraform/kubeconfigs/dr.yaml"; do
    echo "[INFO] Waiting for cluster kubeconfig: $CFG"
    for i in {1..60}; do
      if kubectl --kubeconfig "$CFG" get nodes >/dev/null 2>&1; then
        echo "[INFO] Cluster reachable for $CFG"
        break
      fi
      echo "[INFO] Retry $i: cluster not reachable yet for $CFG, sleeping 15s"
      sleep 15
    done
  done

  echo "[INFO] Deploy PR active (is_failed=false)"
  cd "$repo_root"
  ansible-playbook ansible/failover.yml -e is_failed=false

  echo "[INFO] Trigger DR failover (is_failed=true)"
  ansible-playbook ansible/failover.yml -e is_failed=true

  echo "[INFO] Completed full PR-DR run at $(date)"
} | tee "$LOGFILE"

echo "$LOGFILE"
