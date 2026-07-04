<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Container App

Terraform module for Azure Container Apps, in the Libre DevOps style: fast to get going, secure
by default, flexible when it matters. Deploys into a
`libre-devops/container-app-environment/azurerm` managed environment.

[![CI](https://github.com/libre-devops/terraform-azurerm-container-app/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-container-app/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-container-app?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-container-app/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-container-app)](./LICENSE)

---

## Overview

```hcl
module "container_app" {
  source  = "libre-devops/container-app/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-dev-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  container_apps = {
    "ca-ldo-uks-dev-001" = {
      container_app_environment_id = module.container_app_environment.container_app_environment_ids["cae-ldo-uks-dev-001"]

      ingress = { target_port = 80, external_enabled = true }

      template = {
        containers = [{ name = "web", image = "nginx:1.27-alpine", cpu = 0.25, memory = "0.5Gi" }]
      }
    }
  }
}
```

That entry runs nginx behind a public ingress FQDN. Every knob is an explicit override.

- **Apps as a map.** Deploy many apps into one environment in a single call.
- **Revisions and traffic.** `revision_mode` defaults to Single (newest revision takes all
  traffic); set Multiple and use `ingress.traffic_weights` for blue/green splits.
- **Secrets done right.** Define `secrets` from a literal or a Key Vault reference and consume
  them from container env with `secret_name` or from a `registry` with `password_secret_name`,
  so nothing sensitive lives in plain app settings.
- **Scale to zero and back.** `min_replicas`/`max_replicas` plus http, tcp, azure-queue, and
  custom (KEDA) scale rules; the module wires the azure-queue rule's required authentication.
- **The full template.** Multiple containers plus run-to-completion init containers, cpu/memory,
  env, volume mounts, and liveness/readiness/startup probes; ingress with CORS and IP
  restrictions; dapr; and identity for pulling images or reaching Azure services.

## Examples

- [`examples/minimal`](./examples/minimal) - an environment and one nginx app with external
  ingress, applied, curled, and destroyed in CI.
- [`examples/complete`](./examples/complete) - an app with a secret, an env var sourced from it,
  a liveness probe, an http scale rule with min/max replicas, ingress CORS, and a system-assigned
  identity, on an environment wired to a Log Analytics workspace.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.80.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_container_app.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_container_apps"></a> [container\_apps](#input\_container\_apps) | Container apps keyed by name, deployed into a container app environment. Fast to get going: an<br/>entry with an environment id and one container (name, image, cpu, memory) runs. Flexible when<br/>it matters: ingress, scaling, secrets, registries, dapr, identity, init containers, probes,<br/>and volumes are all here.<br/><br/>REVISION: revision\_mode defaults to Single (the newest revision takes all traffic); set<br/>Multiple for blue/green with traffic\_weights. INGRESS: pass an ingress block with a<br/>target\_port to expose the app; external\_enabled true gives a public FQDN, false keeps it<br/>internal to the environment. SECRETS: define secrets (from a value or a Key Vault reference)<br/>and reference them from container env with secret\_name, or from a registry with<br/>password\_secret\_name. | <pre>map(object({<br/>    container_app_environment_id = string<br/>    revision_mode                = optional(string, "Single")<br/>    workload_profile_name        = optional(string)<br/>    max_inactive_revisions       = optional(number)<br/><br/>    identity = optional(object({<br/>      type         = string<br/>      identity_ids = optional(list(string))<br/>    }))<br/><br/>    secrets = optional(list(object({<br/>      name                = string<br/>      value               = optional(string)<br/>      key_vault_secret_id = optional(string)<br/>      identity            = optional(string)<br/>    })), [])<br/><br/>    registries = optional(list(object({<br/>      server               = string<br/>      username             = optional(string)<br/>      password_secret_name = optional(string)<br/>      identity             = optional(string)<br/>    })), [])<br/><br/>    dapr = optional(object({<br/>      app_id       = string<br/>      app_port     = optional(number)<br/>      app_protocol = optional(string)<br/>    }))<br/><br/>    ingress = optional(object({<br/>      target_port                = number<br/>      exposed_port               = optional(number)<br/>      external_enabled           = optional(bool, false)<br/>      allow_insecure_connections = optional(bool)<br/>      client_certificate_mode    = optional(string)<br/>      transport                  = optional(string)<br/><br/>      traffic_weights = optional(list(object({<br/>        percentage      = number<br/>        latest_revision = optional(bool)<br/>        revision_suffix = optional(string)<br/>        label           = optional(string)<br/>      })), [])<br/><br/>      cors = optional(object({<br/>        allowed_origins           = list(string)<br/>        allowed_headers           = optional(list(string))<br/>        allowed_methods           = optional(list(string))<br/>        exposed_headers           = optional(list(string))<br/>        allow_credentials_enabled = optional(bool)<br/>        max_age_in_seconds        = optional(number)<br/>      }))<br/><br/>      ip_security_restrictions = optional(list(object({<br/>        name             = string<br/>        action           = string<br/>        ip_address_range = string<br/>        description      = optional(string)<br/>      })), [])<br/>    }))<br/><br/>    template = object({<br/>      min_replicas                     = optional(number)<br/>      max_replicas                     = optional(number)<br/>      revision_suffix                  = optional(string)<br/>      cooldown_period_in_seconds       = optional(number)<br/>      polling_interval_in_seconds      = optional(number)<br/>      termination_grace_period_seconds = optional(number)<br/><br/>      containers = list(object({<br/>        name    = string<br/>        image   = string<br/>        cpu     = number<br/>        memory  = string<br/>        args    = optional(list(string))<br/>        command = optional(list(string))<br/><br/>        env = optional(list(object({<br/>          name        = string<br/>          value       = optional(string)<br/>          secret_name = optional(string)<br/>        })), [])<br/><br/>        volume_mounts = optional(list(object({<br/>          name     = string<br/>          path     = string<br/>          sub_path = optional(string)<br/>        })), [])<br/><br/>        liveness_probe = optional(object({<br/>          port                    = number<br/>          transport               = string<br/>          host                    = optional(string)<br/>          path                    = optional(string)<br/>          initial_delay           = optional(number)<br/>          interval_seconds        = optional(number)<br/>          timeout                 = optional(number)<br/>          failure_count_threshold = optional(number)<br/>          headers = optional(list(object({<br/>            name  = string<br/>            value = string<br/>          })), [])<br/>        }))<br/><br/>        readiness_probe = optional(object({<br/>          port                    = number<br/>          transport               = string<br/>          host                    = optional(string)<br/>          path                    = optional(string)<br/>          interval_seconds        = optional(number)<br/>          timeout                 = optional(number)<br/>          failure_count_threshold = optional(number)<br/>          success_count_threshold = optional(number)<br/>          headers = optional(list(object({<br/>            name  = string<br/>            value = string<br/>          })), [])<br/>        }))<br/><br/>        startup_probe = optional(object({<br/>          port                    = number<br/>          transport               = string<br/>          host                    = optional(string)<br/>          path                    = optional(string)<br/>          interval_seconds        = optional(number)<br/>          timeout                 = optional(number)<br/>          failure_count_threshold = optional(number)<br/>          headers = optional(list(object({<br/>            name  = string<br/>            value = string<br/>          })), [])<br/>        }))<br/>      }))<br/><br/>      init_containers = optional(list(object({<br/>        name    = string<br/>        image   = string<br/>        cpu     = optional(number)<br/>        memory  = optional(string)<br/>        args    = optional(list(string))<br/>        command = optional(list(string))<br/>        env = optional(list(object({<br/>          name        = string<br/>          value       = optional(string)<br/>          secret_name = optional(string)<br/>        })), [])<br/>        volume_mounts = optional(list(object({<br/>          name     = string<br/>          path     = string<br/>          sub_path = optional(string)<br/>        })), [])<br/>      })), [])<br/><br/>      volumes = optional(list(object({<br/>        name          = string<br/>        storage_type  = optional(string)<br/>        storage_name  = optional(string)<br/>        mount_options = optional(string)<br/>      })), [])<br/><br/>      http_scale_rules = optional(list(object({<br/>        name                = string<br/>        concurrent_requests = number<br/>        authentications = optional(list(object({<br/>          secret_name       = string<br/>          trigger_parameter = string<br/>        })), [])<br/>      })), [])<br/><br/>      tcp_scale_rules = optional(list(object({<br/>        name                = string<br/>        concurrent_requests = number<br/>        authentications = optional(list(object({<br/>          secret_name       = string<br/>          trigger_parameter = string<br/>        })), [])<br/>      })), [])<br/><br/>      azure_queue_scale_rules = optional(list(object({<br/>        name         = string<br/>        queue_name   = string<br/>        queue_length = number<br/>        authentications = list(object({<br/>          secret_name       = string<br/>          trigger_parameter = string<br/>        }))<br/>      })), [])<br/><br/>      custom_scale_rules = optional(list(object({<br/>        name             = string<br/>        custom_rule_type = string<br/>        metadata         = map(string)<br/>        identity_id      = optional(string)<br/>        authentications = optional(list(object({<br/>          secret_name       = string<br/>          trigger_parameter = string<br/>        })), [])<br/>      })), [])<br/>    })<br/><br/>    tags = optional(map(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for all apps in this module. | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Id of the resource group the apps live in; the module parses the name from it. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all apps; per-app tags override these. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_app_ids"></a> [container\_app\_ids](#output\_container\_app\_ids) | Map of app name to id. |
| <a name="output_container_app_ids_zipmap"></a> [container\_app\_ids\_zipmap](#output\_container\_app\_ids\_zipmap) | Map of app name to { name, id } for easy composition. |
| <a name="output_container_apps"></a> [container\_apps](#output\_container\_apps) | Map of app name to the full container app object. Sensitive as a whole because it carries secret values; the ids, FQDNs, and identity maps alongside stay plain for composition. |
| <a name="output_identity_principal_ids"></a> [identity\_principal\_ids](#output\_identity\_principal\_ids) | Map of app name to { system\_assigned } principal id (null where absent). |
| <a name="output_latest_revision_fqdns"></a> [latest\_revision\_fqdns](#output\_latest\_revision\_fqdns) | Map of app name to the latest revision's ingress FQDN (apps with ingress). |
<!-- END_TF_DOCS -->
