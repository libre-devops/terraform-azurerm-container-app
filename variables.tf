variable "container_apps" {
  description = <<-DESC
    Container apps keyed by name, deployed into a container app environment. Fast to get going: an
    entry with an environment id and one container (name, image, cpu, memory) runs. Flexible when
    it matters: ingress, scaling, secrets, registries, dapr, identity, init containers, probes,
    and volumes are all here.

    REVISION: revision_mode defaults to Single (the newest revision takes all traffic); set
    Multiple for blue/green with traffic_weights. INGRESS: pass an ingress block with a
    target_port to expose the app; external_enabled true gives a public FQDN, false keeps it
    internal to the environment. SECRETS: define secrets (from a value or a Key Vault reference)
    and reference them from container env with secret_name, or from a registry with
    password_secret_name.
  DESC
  type = map(object({
    container_app_environment_id = string
    revision_mode                = optional(string, "Single")
    workload_profile_name        = optional(string)
    max_inactive_revisions       = optional(number)

    identity = optional(object({
      type         = string
      identity_ids = optional(list(string))
    }))

    secrets = optional(list(object({
      name                = string
      value               = optional(string)
      key_vault_secret_id = optional(string)
      identity            = optional(string)
    })), [])

    registries = optional(list(object({
      server               = string
      username             = optional(string)
      password_secret_name = optional(string)
      identity             = optional(string)
    })), [])

    dapr = optional(object({
      app_id       = string
      app_port     = optional(number)
      app_protocol = optional(string)
    }))

    ingress = optional(object({
      target_port                = number
      exposed_port               = optional(number)
      external_enabled           = optional(bool, false)
      allow_insecure_connections = optional(bool)
      client_certificate_mode    = optional(string)
      transport                  = optional(string)

      traffic_weights = optional(list(object({
        percentage      = number
        latest_revision = optional(bool)
        revision_suffix = optional(string)
        label           = optional(string)
      })), [])

      cors = optional(object({
        allowed_origins           = list(string)
        allowed_headers           = optional(list(string))
        allowed_methods           = optional(list(string))
        exposed_headers           = optional(list(string))
        allow_credentials_enabled = optional(bool)
        max_age_in_seconds        = optional(number)
      }))

      ip_security_restrictions = optional(list(object({
        name             = string
        action           = string
        ip_address_range = string
        description      = optional(string)
      })), [])
    }))

    template = object({
      min_replicas                     = optional(number)
      max_replicas                     = optional(number)
      revision_suffix                  = optional(string)
      cooldown_period_in_seconds       = optional(number)
      polling_interval_in_seconds      = optional(number)
      termination_grace_period_seconds = optional(number)

      containers = list(object({
        name    = string
        image   = string
        cpu     = number
        memory  = string
        args    = optional(list(string))
        command = optional(list(string))

        env = optional(list(object({
          name        = string
          value       = optional(string)
          secret_name = optional(string)
        })), [])

        volume_mounts = optional(list(object({
          name     = string
          path     = string
          sub_path = optional(string)
        })), [])

        liveness_probe = optional(object({
          port                    = number
          transport               = string
          host                    = optional(string)
          path                    = optional(string)
          initial_delay           = optional(number)
          interval_seconds        = optional(number)
          timeout                 = optional(number)
          failure_count_threshold = optional(number)
          headers = optional(list(object({
            name  = string
            value = string
          })), [])
        }))

        readiness_probe = optional(object({
          port                    = number
          transport               = string
          host                    = optional(string)
          path                    = optional(string)
          interval_seconds        = optional(number)
          timeout                 = optional(number)
          failure_count_threshold = optional(number)
          success_count_threshold = optional(number)
          headers = optional(list(object({
            name  = string
            value = string
          })), [])
        }))

        startup_probe = optional(object({
          port                    = number
          transport               = string
          host                    = optional(string)
          path                    = optional(string)
          interval_seconds        = optional(number)
          timeout                 = optional(number)
          failure_count_threshold = optional(number)
          headers = optional(list(object({
            name  = string
            value = string
          })), [])
        }))
      }))

      init_containers = optional(list(object({
        name    = string
        image   = string
        cpu     = optional(number)
        memory  = optional(string)
        args    = optional(list(string))
        command = optional(list(string))
        env = optional(list(object({
          name        = string
          value       = optional(string)
          secret_name = optional(string)
        })), [])
        volume_mounts = optional(list(object({
          name     = string
          path     = string
          sub_path = optional(string)
        })), [])
      })), [])

      volumes = optional(list(object({
        name          = string
        storage_type  = optional(string)
        storage_name  = optional(string)
        mount_options = optional(string)
      })), [])

      http_scale_rules = optional(list(object({
        name                = string
        concurrent_requests = number
        authentications = optional(list(object({
          secret_name       = string
          trigger_parameter = string
        })), [])
      })), [])

      tcp_scale_rules = optional(list(object({
        name                = string
        concurrent_requests = number
        authentications = optional(list(object({
          secret_name       = string
          trigger_parameter = string
        })), [])
      })), [])

      azure_queue_scale_rules = optional(list(object({
        name         = string
        queue_name   = string
        queue_length = number
        authentications = list(object({
          secret_name       = string
          trigger_parameter = string
        }))
      })), [])

      custom_scale_rules = optional(list(object({
        name             = string
        custom_rule_type = string
        metadata         = map(string)
        identity_id      = optional(string)
        authentications = optional(list(object({
          secret_name       = string
          trigger_parameter = string
        })), [])
      })), [])
    })

    tags = optional(map(string))
  }))
  default = {}

  validation {
    condition     = alltrue([for a in values(var.container_apps) : contains(["Single", "Multiple"], a.revision_mode)])
    error_message = "revision_mode must be Single or Multiple."
  }

  validation {
    condition     = alltrue([for a in values(var.container_apps) : length(a.template.containers) > 0])
    error_message = "Each container app needs at least one container in its template."
  }
}

variable "location" {
  description = "Azure region for all apps in this module."
  type        = string
}

variable "resource_group_id" {
  description = "Id of the resource group the apps live in; the module parses the name from it."
  type        = string
}

variable "tags" {
  description = "Tags applied to all apps; per-app tags override these."
  type        = map(string)
  default     = {}
}
