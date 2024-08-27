variable "hcp_terraform_fqdn" {
  default     = "app.terraform.io"
  description = "The FQDN of the HCP Terraform OIDC provider"
  type        = string
}

variable "client_id_list" {
  default     = ["aws.workload.identity"]
  description = "The list of client IDs"
  type        = list(string)
}

variable "iam_roles" {
  default     = {}
  description = "A map of IAM Roles to create."
  type = map(object({
    description  = optional(string, "HCP Terraform OIDC Role")
    subject_name = string
    account_id   = string
    permissions  = optional(list(string), [])
  }))
}
