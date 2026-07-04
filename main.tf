locals {
  rg = provider::azurerm::parse_resource_id(var.resource_group_id)
}

resource "azurerm_container_app" "this" {
  for_each = var.container_apps

  resource_group_name = local.rg.resource_group_name
  tags                = merge(var.tags, coalesce(each.value.tags, {}))

  name                         = each.key
  container_app_environment_id = each.value.container_app_environment_id
  revision_mode                = each.value.revision_mode
  workload_profile_name        = each.value.workload_profile_name
  max_inactive_revisions       = each.value.max_inactive_revisions

  dynamic "identity" {
    for_each = each.value.identity != null ? [each.value.identity] : []

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "secret" {
    for_each = { for s in each.value.secrets : s.name => s }

    content {
      name                = secret.value.name
      value               = secret.value.value
      key_vault_secret_id = secret.value.key_vault_secret_id
      identity            = secret.value.identity
    }
  }

  dynamic "registry" {
    for_each = { for r in each.value.registries : r.server => r }

    content {
      server               = registry.value.server
      username             = registry.value.username
      password_secret_name = registry.value.password_secret_name
      identity             = registry.value.identity
    }
  }

  dynamic "dapr" {
    for_each = each.value.dapr != null ? [each.value.dapr] : []

    content {
      app_id       = dapr.value.app_id
      app_port     = dapr.value.app_port
      app_protocol = dapr.value.app_protocol
    }
  }

  dynamic "ingress" {
    for_each = each.value.ingress != null ? [each.value.ingress] : []

    content {
      target_port                = ingress.value.target_port
      exposed_port               = ingress.value.exposed_port
      external_enabled           = ingress.value.external_enabled
      allow_insecure_connections = ingress.value.allow_insecure_connections
      client_certificate_mode    = ingress.value.client_certificate_mode
      transport                  = ingress.value.transport

      dynamic "traffic_weight" {
        for_each = length(ingress.value.traffic_weights) > 0 ? ingress.value.traffic_weights : [{ percentage = 100, latest_revision = true, revision_suffix = null, label = null }]

        content {
          percentage      = traffic_weight.value.percentage
          latest_revision = traffic_weight.value.latest_revision
          revision_suffix = traffic_weight.value.revision_suffix
          label           = traffic_weight.value.label
        }
      }

      dynamic "cors" {
        for_each = ingress.value.cors != null ? [ingress.value.cors] : []

        content {
          allowed_origins           = cors.value.allowed_origins
          allowed_headers           = cors.value.allowed_headers
          allowed_methods           = cors.value.allowed_methods
          exposed_headers           = cors.value.exposed_headers
          allow_credentials_enabled = cors.value.allow_credentials_enabled
          max_age_in_seconds        = cors.value.max_age_in_seconds
        }
      }

      dynamic "ip_security_restriction" {
        for_each = ingress.value.ip_security_restrictions

        content {
          name             = ip_security_restriction.value.name
          action           = ip_security_restriction.value.action
          ip_address_range = ip_security_restriction.value.ip_address_range
          description      = ip_security_restriction.value.description
        }
      }
    }
  }

  template {
    min_replicas                     = each.value.template.min_replicas
    max_replicas                     = each.value.template.max_replicas
    revision_suffix                  = each.value.template.revision_suffix
    cooldown_period_in_seconds       = each.value.template.cooldown_period_in_seconds
    polling_interval_in_seconds      = each.value.template.polling_interval_in_seconds
    termination_grace_period_seconds = each.value.template.termination_grace_period_seconds

    dynamic "container" {
      for_each = { for c in each.value.template.containers : c.name => c }

      content {
        name    = container.value.name
        image   = container.value.image
        cpu     = container.value.cpu
        memory  = container.value.memory
        args    = container.value.args
        command = container.value.command

        dynamic "env" {
          for_each = { for e in container.value.env : e.name => e }

          content {
            name        = env.value.name
            value       = env.value.value
            secret_name = env.value.secret_name
          }
        }

        dynamic "volume_mounts" {
          for_each = container.value.volume_mounts

          content {
            name     = volume_mounts.value.name
            path     = volume_mounts.value.path
            sub_path = volume_mounts.value.sub_path
          }
        }

        dynamic "liveness_probe" {
          for_each = container.value.liveness_probe != null ? [container.value.liveness_probe] : []

          content {
            port                    = liveness_probe.value.port
            transport               = liveness_probe.value.transport
            host                    = liveness_probe.value.host
            path                    = liveness_probe.value.path
            initial_delay           = liveness_probe.value.initial_delay
            interval_seconds        = liveness_probe.value.interval_seconds
            timeout                 = liveness_probe.value.timeout
            failure_count_threshold = liveness_probe.value.failure_count_threshold

            dynamic "header" {
              for_each = liveness_probe.value.headers
              content {
                name  = header.value.name
                value = header.value.value
              }
            }
          }
        }

        dynamic "readiness_probe" {
          for_each = container.value.readiness_probe != null ? [container.value.readiness_probe] : []

          content {
            port                    = readiness_probe.value.port
            transport               = readiness_probe.value.transport
            host                    = readiness_probe.value.host
            path                    = readiness_probe.value.path
            interval_seconds        = readiness_probe.value.interval_seconds
            timeout                 = readiness_probe.value.timeout
            failure_count_threshold = readiness_probe.value.failure_count_threshold
            success_count_threshold = readiness_probe.value.success_count_threshold

            dynamic "header" {
              for_each = readiness_probe.value.headers
              content {
                name  = header.value.name
                value = header.value.value
              }
            }
          }
        }

        dynamic "startup_probe" {
          for_each = container.value.startup_probe != null ? [container.value.startup_probe] : []

          content {
            port                    = startup_probe.value.port
            transport               = startup_probe.value.transport
            host                    = startup_probe.value.host
            path                    = startup_probe.value.path
            interval_seconds        = startup_probe.value.interval_seconds
            timeout                 = startup_probe.value.timeout
            failure_count_threshold = startup_probe.value.failure_count_threshold

            dynamic "header" {
              for_each = startup_probe.value.headers
              content {
                name  = header.value.name
                value = header.value.value
              }
            }
          }
        }
      }
    }

    dynamic "init_container" {
      for_each = { for c in each.value.template.init_containers : c.name => c }

      content {
        name    = init_container.value.name
        image   = init_container.value.image
        cpu     = init_container.value.cpu
        memory  = init_container.value.memory
        args    = init_container.value.args
        command = init_container.value.command

        dynamic "env" {
          for_each = { for e in init_container.value.env : e.name => e }

          content {
            name        = env.value.name
            value       = env.value.value
            secret_name = env.value.secret_name
          }
        }

        dynamic "volume_mounts" {
          for_each = init_container.value.volume_mounts

          content {
            name     = volume_mounts.value.name
            path     = volume_mounts.value.path
            sub_path = volume_mounts.value.sub_path
          }
        }
      }
    }

    dynamic "volume" {
      for_each = { for v in each.value.template.volumes : v.name => v }

      content {
        name          = volume.value.name
        storage_type  = volume.value.storage_type
        storage_name  = volume.value.storage_name
        mount_options = volume.value.mount_options
      }
    }

    dynamic "http_scale_rule" {
      for_each = { for r in each.value.template.http_scale_rules : r.name => r }

      content {
        name                = http_scale_rule.value.name
        concurrent_requests = http_scale_rule.value.concurrent_requests

        dynamic "authentication" {
          for_each = http_scale_rule.value.authentications
          content {
            secret_name       = authentication.value.secret_name
            trigger_parameter = authentication.value.trigger_parameter
          }
        }
      }
    }

    dynamic "tcp_scale_rule" {
      for_each = { for r in each.value.template.tcp_scale_rules : r.name => r }

      content {
        name                = tcp_scale_rule.value.name
        concurrent_requests = tcp_scale_rule.value.concurrent_requests

        dynamic "authentication" {
          for_each = tcp_scale_rule.value.authentications
          content {
            secret_name       = authentication.value.secret_name
            trigger_parameter = authentication.value.trigger_parameter
          }
        }
      }
    }

    dynamic "azure_queue_scale_rule" {
      for_each = { for r in each.value.template.azure_queue_scale_rules : r.name => r }

      content {
        name         = azure_queue_scale_rule.value.name
        queue_name   = azure_queue_scale_rule.value.queue_name
        queue_length = azure_queue_scale_rule.value.queue_length

        dynamic "authentication" {
          for_each = azure_queue_scale_rule.value.authentications
          content {
            secret_name       = authentication.value.secret_name
            trigger_parameter = authentication.value.trigger_parameter
          }
        }
      }
    }

    dynamic "custom_scale_rule" {
      for_each = { for r in each.value.template.custom_scale_rules : r.name => r }

      content {
        name             = custom_scale_rule.value.name
        custom_rule_type = custom_scale_rule.value.custom_rule_type
        metadata         = custom_scale_rule.value.metadata
        identity_id      = custom_scale_rule.value.identity_id

        dynamic "authentication" {
          for_each = custom_scale_rule.value.authentications
          content {
            secret_name       = authentication.value.secret_name
            trigger_parameter = authentication.value.trigger_parameter
          }
        }
      }
    }
  }
}
