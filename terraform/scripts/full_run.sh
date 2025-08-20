#!/usr/bin/env bash
set -euo pipefail
LOGFILE="logs/run-$(date +%Y%m%d-%H%M%S).log"
{
  echo "[INFO] Starting full PR-DR run at $(date)"
  PROJECT_ID=$(gcloud config get-value project)
  export TF_VAR_project_id="$PROJECT_ID"
  echo "[INFO] Using GCP project: $PROJECT_ID"

  echo "[INFO] Terraform init/apply..."
  cd terraform
  terraform init -input=false -upgrade -backend=false
  terraform apply -auto-approve

  echo "[INFO] Terraform apply completed at $(date)"
  echo "[INFO] Verifying clusters are reachable..."
  for CFG in kubeconfigs/pr.yaml kubeconfigs/dr.yaml; do
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
  cd ..

  echo "[INFO] Deploy PR active (is_failed=false)"
  ansible-playbook ansible/failover.yml -e is_failed=false

  echo "[INFO] Trigger DR failover (is_failed=true)"
  ansible-playbook ansible/failover.yml -e is_failed=true

  echo "[INFO] Completed full PR-DR run at $(date)"
} | tee "$LOGFILE"

# Print log path for convenience
echo "$LOGFILE"
