terraform {
  required_version = ">= 1.5.0"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.19.0"
    }
  }
}

provider "grafana" {
  alias                     = "cloud"
  cloud_access_policy_token = var.cloud_access_policy_token
}

data "grafana_cloud_stack" "this" {
  provider = grafana.cloud
  slug     = var.stack_slug
}

resource "grafana_cloud_access_policy" "fleet_management" {
  provider     = grafana.cloud
  region       = data.grafana_cloud_stack.this.region_slug
  name         = "${var.stack_slug}-fleet-management-tf"
  display_name = "Fleet Management (Terraform-managed)"

  scopes = [
    "fleet-management:read",
    "fleet-management:write",
  ]

  realm {
    type       = "stack"
    identifier = data.grafana_cloud_stack.this.id
  }
}

resource "grafana_cloud_access_policy_token" "fleet_management" {
  provider         = grafana.cloud
  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.fleet_management.policy_id
  name             = "${var.stack_slug}-fleet-management-tf"
}

provider "grafana" {
  alias                 = "fm"
  fleet_management_url  = data.grafana_cloud_stack.this.fleet_management_url
  fleet_management_auth = "${data.grafana_cloud_stack.this.fleet_management_user_id}:${grafana_cloud_access_policy_token.fleet_management.token}"
}
