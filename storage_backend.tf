# storage_backend.tf
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
# }

# resource "azurerm_storage_container" "tfstate" {
#   name                  = "tfstate"
#   storage_account_id    = azurerm_storage_account.tfstate.id
#   container_access_type = "private"
# }