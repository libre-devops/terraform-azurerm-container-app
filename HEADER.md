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
