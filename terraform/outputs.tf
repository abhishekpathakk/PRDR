output "pr_kubeconfig" {
  description = "Path to PR kubeconfig"
  value       = "${path.module}/kubeconfigs/pr.yaml"
}

output "dr_kubeconfig" {
  description = "Path to DR kubeconfig"
  value       = "${path.module}/kubeconfigs/dr.yaml"
}
