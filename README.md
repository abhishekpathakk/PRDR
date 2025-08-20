## PR-DR Failover Simulation on GKE (Terraform + Ansible + Helm)

This repo simulates a Primary–Disaster Recovery (PR–DR) setup on Google Kubernetes Engine (GKE) using:
- Terraform for infra provisioning (2 clusters: PR and DR)
- Helm for deploying a lightweight, ping-capable workload
- Ansible to orchestrate failover using a boolean flag `is_failed`

When `is_failed=false`: PR is active, DR is standby (0 replicas).
When `is_failed=true`: DR becomes active, PR scales to 0 replicas.

### Architecture
- Two GKE clusters in different regions: `pr` and `dr`
- Namespace `mesh` in each cluster
- A Helm release `pingmesh` runs `busybox` pods that can ping peers
- Ansible toggles replica counts between clusters and runs connectivity checks

### Prerequisites
- gcloud SDK installed and authenticated
- Terraform >= 1.3
- Ansible >= 2.14
- Helm >= 3.10
- kubectl >= 1.26
- A Google Cloud project with billing enabled

Auth and project setup:
```bash
# Authenticate user and set project
gcloud auth login

# Also provide Application Default Credentials for Terraform
gcloud auth application-default login

gcloud config set project <YOUR_GCP_PROJECT_ID>

# Export for Terraform variables
export TF_VAR_project_id=<YOUR_GCP_PROJECT_ID>
```

### Deploy Infrastructure (Terraform)
```bash
cd terraform
terraform init
terraform apply -auto-approve
```
This creates two GKE clusters and writes kubeconfigs:
- `kubeconfigs/pr.yaml`
- `kubeconfigs/dr.yaml`

Test connectivity to each cluster:
```bash
kubectl --kubeconfig kubeconfigs/pr.yaml get nodes
kubectl --kubeconfig kubeconfigs/dr.yaml get nodes
```

### Deploy App and Orchestrate Failover (Ansible + Helm)
Initial deploy (PR active, DR standby):
```bash
ansible-playbook ansible/failover.yml -e is_failed=false
```
Failover (DR becomes active, PR standby):
```bash
ansible-playbook ansible/failover.yml -e is_failed=true
```

The playbook:
- Ensures namespaces exist
- Installs/updates the `pingmesh` Helm release with appropriate `replicaCount`
- Runs a ping mesh test from one pod to all others in the active site

### Clean Up
```bash
cd terraform
terraform destroy -auto-approve
```

### Notes
- Busybox includes `ping`, so pods can verify interconnectivity.
- Kubeconfigs use gcloud exec auth; keep gcloud installed.
- Adjust regions, machine types, and replicas via Terraform variables or Ansible vars as needed.
