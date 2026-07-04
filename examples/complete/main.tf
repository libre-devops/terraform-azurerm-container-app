# The module's surface: a managed environment (with a workspace) hosting a container app with a
# secret, an environment variable sourced from it, a liveness probe, an http scale rule with
# min/max replicas, CORS on the ingress, and a system-assigned identity. Applied, curled, then
# destroyed in one CI run.
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  cae_name = "cae-${var.short}-${var.loc}-${terraform.workspace}-002"
  ca_name  = "ca-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-container-app" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = { (local.law_name) = {} }
}

module "container_app_environment" {
  source  = "libre-devops/container-app-environment/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  container_app_environments = {
    (local.cae_name) = {
      log_analytics_workspace_id = module.log_analytics.workspace_ids[local.law_name]
    }
  }
}

module "container_app" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  container_apps = {
    (local.ca_name) = {
      container_app_environment_id = module.container_app_environment.container_app_environment_ids[local.cae_name]

      identity = { type = "SystemAssigned" }

      secrets = [
        { name = "greeting", value = "hello-from-container-apps" }
      ]

      ingress = {
        target_port      = 80
        external_enabled = true

        cors = {
          allowed_origins = ["https://portal.azure.com"]
        }
      }

      template = {
        min_replicas = 1
        max_replicas = 3

        containers = [
          {
            name   = "web"
            image  = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
            cpu    = 0.25
            memory = "0.5Gi"

            env = [
              { name = "GREETING", secret_name = "greeting" }
            ]

            liveness_probe = {
              port      = 80
              transport = "HTTP"
              path      = "/"
            }
          }
        ]

        http_scale_rules = [
          { name = "http", concurrent_requests = 50 }
        ]
      }

      tags = { Component = "web" }
    }
  }
}

output "app_fqdn" {
  value = module.container_app.latest_revision_fqdns[local.ca_name]
}

output "resource_group_name" {
  value = local.rg_name
}
