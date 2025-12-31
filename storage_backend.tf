# storage_backend.tf
# This file creates the Azure Storage infrastructure to store Terraform state remotely
# This is a one-time setup and should be commented out after initial creation
# ⚠️ IMPORTANT: Keep this commented out to prevent Terraform from managing the state storage itself!

# resource "azurerm_resource_group" "tfstate" {
#   name     = "tfstate-rg"
#   location = "uksouth"
# }

# resource "azurerm_storage_account" "tfstate" {
#   name                     = "cadescloudtfstate01" # must be globally unique, 3-24 lowercase letters/numbers
#   resource_group_name      = azurerm_resource_group.tfstate.name
#   location                 = azurerm_resource_group.tfstate.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   
#   # Enable versioning for state file recovery
#   blob_properties {
#     versioning_enabled = true
#   }
#   
#   tags = {
#     purpose     = "terraform-state"
#     managed_by  = "terraform"
#   }
# }

# resource "azurerm_storage_container" "tfstate" {
#   name                  = "tfstate"
#   storage_account_name  = azurerm_storage_account.tfstate.name
#   container_access_type = "private"
# }