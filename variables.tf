variable "azure_subscription_id" {
  type        = string
  description = "Your Azure subscription ID."
}

variable "owner_email" {
  type        = string
  description = "Your email address."
}

variable "public_key_path" {
  type        = string
  description = "Path to your SSH key public key."
}

variable "stackit_organization_id" {
  type        = string
  description = "Your STACKIT organization ID."
}

variable "stackit_service_account_key_path" {
  type        = string
  description = "Path to your STACKIT service account key JSON file."
}
