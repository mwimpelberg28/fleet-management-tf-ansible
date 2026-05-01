# Pipeline content uses sys.env("GCLOUD_RW_API_KEY") for the write token; that
# env var is provisioned on each host by ansible (see
# ansible/*/templates/alloy.env.j2). Stack URLs and instance IDs are read from
# the grafana_cloud_stack data source so this module only needs the stack slug.

locals {
  pipeline_template_vars = {
    metrics_url = data.grafana_cloud_stack.this.prometheus_remote_write_endpoint
    metrics_id  = data.grafana_cloud_stack.this.prometheus_user_id
    logs_url    = data.grafana_cloud_stack.this.logs_url
    logs_id     = data.grafana_cloud_stack.this.logs_user_id
  }
}

resource "grafana_fleet_management_pipeline" "linux_host" {
  provider = grafana.fm

  name     = "linux_host"
  contents = templatefile("${path.module}/pipelines/linux_host.alloy.tftpl", local.pipeline_template_vars)

  matchers = [
    "collector.os=\"linux\"",
    "env=\"${var.environment}\"",
  ]

  enabled = true
}

resource "grafana_fleet_management_pipeline" "windows_host" {
  provider = grafana.fm

  name     = "windows_host"
  contents = templatefile("${path.module}/pipelines/windows_host.alloy.tftpl", local.pipeline_template_vars)

  matchers = [
    "collector.os=\"windows\"",
    "env=\"${var.environment}\"",
  ]

  enabled = true
}
