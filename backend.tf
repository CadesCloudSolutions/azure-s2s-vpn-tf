terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.42.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }

  backend "azurerm" {
    resource_group_name   = "tfstate-rg"
    storage_account_name  = "cadescloudtfstate01"
    container_name        = "tfstate"
    key                   = "hub-spoke/terraform.tfstate"
  }
}
