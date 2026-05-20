output "cluster_config" {
  sensitive = true
  value     = module.halvnais.cluster_config
}

output "pending_role_assignments" {
  value = module.halvnais.pending_role_assignments
}
