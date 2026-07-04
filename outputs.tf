output "container_app_ids" {
  description = "Map of app name to id."
  value       = { for k, a in azurerm_container_app.this : k => a.id }
}

output "container_app_ids_zipmap" {
  description = "Map of app name to { name, id } for easy composition."
  value       = { for k, a in azurerm_container_app.this : k => { name = a.name, id = a.id } }
}

output "container_apps" {
  description = "Map of app name to the full container app object. Sensitive as a whole because it carries secret values; the ids, FQDNs, and identity maps alongside stay plain for composition."
  value       = azurerm_container_app.this
  sensitive   = true
}

output "identity_principal_ids" {
  description = "Map of app name to { system_assigned } principal id (null where absent)."
  value = {
    for k, a in azurerm_container_app.this : k => {
      system_assigned = try(a.identity[0].principal_id, null)
    }
  }
}

output "latest_revision_fqdns" {
  description = "Map of app name to the latest revision's ingress FQDN (apps with ingress)."
  value       = { for k, a in azurerm_container_app.this : k => a.latest_revision_fqdn }
}
