# Tests for the module. azurerm is mocked (no credentials, no cloud):
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001"
  location          = "uksouth"
  tags              = { Environment = "tst" }
}


# One app, one container: Single revision mode, external ingress.
run "fast_to_get_going" {
  command = apply

  variables {
    container_apps = {
      "ca-ldo-uks-tst-001" = {
        container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.App/managedEnvironments/cae-mock"

        ingress = {
          target_port      = 80
          external_enabled = true
        }

        template = {
          containers = [
            { name = "web", image = "nginx:1.27-alpine", cpu = 0.25, memory = "0.5Gi" }
          ]
        }
      }
    }
  }

  assert {
    condition     = azurerm_container_app.this["ca-ldo-uks-tst-001"].revision_mode == "Single"
    error_message = "revision_mode should default to Single."
  }

  assert {
    condition     = azurerm_container_app.this["ca-ldo-uks-tst-001"].ingress[0].external_enabled == true
    error_message = "External ingress should be configured."
  }
}

# Secrets, a private registry reference, scaling, a probe, and an identity.
run "full_surface" {
  command = apply

  variables {
    container_apps = {
      "ca-ldo-uks-tst-002" = {
        container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.App/managedEnvironments/cae-mock"
        identity                     = { type = "SystemAssigned" }

        secrets = [
          { name = "registry-password", value = "example" }
        ]

        registries = [
          { server = "acrmock.azurecr.io", username = "acrmock", password_secret_name = "registry-password" }
        ]

        ingress = {
          target_port      = 8080
          external_enabled = true
        }

        template = {
          min_replicas = 1
          max_replicas = 5

          containers = [
            {
              name   = "api"
              image  = "acrmock.azurecr.io/api:latest"
              cpu    = 0.5
              memory = "1Gi"
              env = [
                { name = "LOG_LEVEL", value = "info" }
              ]
              liveness_probe = {
                port      = 8080
                transport = "HTTP"
                path      = "/healthz"
              }
            }
          ]

          http_scale_rules = [
            { name = "http", concurrent_requests = 50 }
          ]
        }
      }
    }
  }

  assert {
    condition     = length(azurerm_container_app.this["ca-ldo-uks-tst-002"].secret) == 1
    error_message = "The secret should be configured."
  }

  assert {
    condition     = length(azurerm_container_app.this["ca-ldo-uks-tst-002"].registry) == 1
    error_message = "The registry should be configured."
  }

  assert {
    condition     = azurerm_container_app.this["ca-ldo-uks-tst-002"].identity[0].type == "SystemAssigned"
    error_message = "The identity should be attached."
  }
}

run "rejects_bad_revision_mode" {
  command = plan

  variables {
    container_apps = {
      "ca-ldo-uks-tst-003" = {
        container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.App/managedEnvironments/cae-mock"
        revision_mode                = "Rolling"
        template = {
          containers = [{ name = "web", image = "nginx", cpu = 0.25, memory = "0.5Gi" }]
        }
      }
    }
  }

  expect_failures = [var.container_apps]
}
