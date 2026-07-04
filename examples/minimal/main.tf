# Minimal call: a managed environment and one nginx container app with external ingress,
# reachable on its ingress FQDN. Applied, curled, then destroyed in one CI run.
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  cae_name = "cae-${var.short}-${var.loc}-${terraform.workspace}-001"
  ca_name  = "ca-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "container_app_environment" {
  source  = "libre-devops/container-app-environment/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  container_app_environments = { (local.cae_name) = {} }
}

module "container_app" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  container_apps = {
    (local.ca_name) = {
      container_app_environment_id = module.container_app_environment.container_app_environment_ids[local.cae_name]

      ingress = {
        target_port      = 80
        external_enabled = true
      }

      template = {
        containers = [
          { name = "web", image = "mcr.microsoft.com/azuredocs/aci-helloworld:latest", cpu = 0.25, memory = "0.5Gi" }
        ]
      }
    }
  }
}

output "app_fqdn" {
  value = module.container_app.latest_revision_fqdns[local.ca_name]
}

output "resource_group_name" {
  value = local.rg_name
}
