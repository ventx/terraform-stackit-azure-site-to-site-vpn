provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "stackit" {
  default_region           = "eu01"
  service_account_key_path = var.stackit_service_account_key_path
}
