variable "cloud_access_policy_token" {
  description = "Grafana Cloud access policy token with scopes: stacks:read, accesspolicies:read, accesspolicies:write, accesspolicies:delete. Used to look up the stack and provision the Fleet Management token."
  type        = string
  sensitive   = true
}

variable "stack_slug" {
  description = "Slug of the Grafana Cloud stack (e.g. 'mystack' from https://mystack.grafana.net)."
  type        = string
}

variable "environment" {
  description = "Value of the 'env' attribute set on collectors via remotecfg. Pipelines target collectors by matching this value."
  type        = string
  default     = "production"
}
