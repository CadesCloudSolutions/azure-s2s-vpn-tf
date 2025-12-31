terraform {
  backend "azurerm" {
    resource_group_name   = "tfstate-rg"
    storage_account_name  = "cadescloudtfstate01"
    container_name        = "tfstate"
    key                   = "hub-spoke/terraform.tfstate"
  }
}

 