output "kubeconfig" {
  description = "The kubeconfig of the SKE cluster."
  value       = stackit_ske_kubeconfig.main.kube_config
  sensitive   = true
}
