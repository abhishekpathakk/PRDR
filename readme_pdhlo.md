## PR-DR Simulation (Hinglish Guide)

Ye repo me humne GKE par Primary-Disaster Recovery (PR-DR) ka end-to-end demo banaya hai. Infra Terraform se, app Helm se, aur failover Ansible se control hota hai. Redis add kiya for simple DB replication demo.

### Architecture me kya hai
- 2 GKE clusters: PR (us-central1-a) aur DR (us-east1-b)
- Single VPC + 2 regional subnets + secondary ranges (Pods/Services)
- Namespace: `mesh`
- App: `pingmesh` (BusyBox StatefulSet + headless Service) -> pods ek dusre ko ping kar sakte
- DB: `redis-lite` chart (LoadBalancer Service) -> simple master/replica across clusters
- Orchestration: `ansible/failover.yml` me `is_failed=true/false` se PR ya DR active banate

### Tools chahiye
- gcloud, Terraform, kubectl, Helm, Ansible

### Pehle ye karo (auth + project)
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <GCP_PROJECT>
export TF_VAR_project_id=<GCP_PROJECT>
```

### Infra banane ka tarika (Terraform)
```bash
cd terraform
terraform init
terraform apply -auto-approve
# Kubeconfigs ban jayenge:
# terraform/kubeconfigs/pr.yaml
# terraform/kubeconfigs/dr.yaml
```

### App deploy + Failover (Ansible + Helm)
- PR active (DR standby):
```bash
ansible-playbook ansible/failover.yml -e is_failed=false
```
- DR active (PR standby):
```bash
ansible-playbook ansible/failover.yml -e is_failed=true
```

### Verify pods
```bash
# PR pods (active site par 3 hone chahiye)
kubectl --kubeconfig terraform/kubeconfigs/pr.yaml -n mesh get pods -l app=pingmesh
# DR pods (standby par 0)
kubectl --kubeconfig terraform/kubeconfigs/dr.yaml -n mesh get pods -l app=pingmesh
```

### Redis replication demo (sab playbook me scripted hai)
- `is_failed=false`:
  - PR -> Master, DR -> Replica
  - Playbook PR par key likhta hai aur DR par read karta hai (MGET output dikhega)
- `is_failed=true`:
  - DR -> Master, PR -> Replica
  - Playbook DR par key likhta hai aur PR par read karta hai

Manual check (optional):
```bash
# PR master context me (jab is_failed=false kiya ho)
PRCFG=terraform/kubeconfigs/pr.yaml
DRCFG=terraform/kubeconfigs/dr.yaml

# PR me write, DR me read
kubectl --kubeconfig "$PRCFG" -n mesh exec deploy/redis -- sh -c \
  'redis-cli SET prdr:site PR && redis-cli SET prdr:last "$(date -Iseconds)"'

kubectl --kubeconfig "$DRCFG" -n mesh exec deploy/redis -- sh -c \
  'redis-cli MGET prdr:site prdr:last'
```

### Full automatic run
```bash
./scripts/full_run.sh &
# Logs: logs/current.log
```

### Clean up (cost bachane ke liye)
- Pehle `terraform/main.tf` me dono clusters ka `deletion_protection = false` set karo
- Fir destroy:
```bash
cd terraform
terraform apply -auto-approve   # if you changed deletion_protection
terraform destroy -auto-approve
```

### Important files
- Terraform: `terraform/` (VPC, subnets, GKE, kubeconfigs)
- Helm (app): `helm/pingmesh/`
- Helm (redis): `helm/redis-lite/`
- Ansible: `ansible/failover.yml`
- Script: `scripts/full_run.sh`

### Kya kiya maine (high-level)
- PR/DR GKE clusters banaye with proper networking
- Busybox mesh app deploy kiya jo pods ko ping karke connectivity verify karta
- Ansible se `is_failed` flag par PR<->DR switchover implement kiya (replicas toggle)
- Redis deploy kiya dono sites par aur cross-cluster replication configure ki
- Dono direction me data replication test kiya (PR->DR aur DR->PR)

