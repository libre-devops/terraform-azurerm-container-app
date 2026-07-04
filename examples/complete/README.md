<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

An app with a secret, an env var sourced from it, a liveness probe, an http scale rule with min/max replicas, ingress CORS, and a system-assigned identity, on an environment wired to a Log Analytics workspace.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
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
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_container_app"></a> [container\_app](#module\_container\_app) | ../../ | n/a |
| <a name="module_container_app_environment"></a> [container\_app\_environment](#module\_container\_app\_environment) | libre-devops/container-app-environment/azurerm | ~> 4.0 |
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_fqdn"></a> [app\_fqdn](#output\_app\_fqdn) | n/a |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | n/a |
<!-- END_TF_DOCS -->
