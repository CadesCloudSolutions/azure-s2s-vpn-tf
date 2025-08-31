variable "location" {
  description = "Azure region"
  default     = "uksouth"
}

variable "hub_rg_name" {
  description = "Hub resource group name"
  default     = "hub-rg"
}

variable "spoke1_rg_name" {
  description = "Spoke 1 resource group name"
  default     = "Spoke1-AVD-RG"
}

variable "spoke2_rg_name" {
  description = "Spoke 2 resource group name"
  default     = "Spoke2-Ctx-RG"
}

variable "hub_vnet_address_space" {
  default = ["10.163.0.0/22"]
}

variable "spoke1_vnet_address_space" {
  default = ["10.125.0.0/24"]
}

variable "spoke2_vnet_address_space" {
  default = ["10.145.0.0/24"]
}

variable "hub_vnet_name" {
  description = "Name of the hub virtual network"
  default     = "hub-vnet"
}

variable "spoke1_vnet_name" {
  description = "Name of the Spoke 1 virtual network"
  default     = "avd-vnet"
}

variable "hub_to_spoke1_peering_name" {
  description = "Peering link name from hub to spoke1"
  default     = "hubtospoke1"
}

variable "spoke1_to_hub_peering_name" {
  description = "Peering link name from spoke1 to hub"
  default     = "spoke1tohub"
}

variable "hub_to_spoke2_peering_name" {
  description = "Peering link name from hub to spoke2"
  default     = "hubtospoke2"
}

variable "spoke2_to_hub_peering_name" {
  description = "Peering link name from spoke2 to hub"
  default     = "spoke2tohub"
}

variable "vpn_shared_key" {
  description = "Shared key for VPN connection"
  type        = string
  sensitive   = true
}

variable "avd_subnet_name" {
  description = "Subnet name for AVD VM"
  default     = "avd-subnet"
}

variable "avd_subnet_prefix" {
  description = "Address prefix for AVD subnet"
  default     = "10.125.0.0/27"
}

variable "ctx_subnet_name" {
  description = "Subnet name for Citrix VM"
  default     = "ctx-subnet"
}

variable "ctx_subnet_prefix" {
  description = "Address prefix for Citrix subnet"
  default     = "10.145.0.0/27"
}

variable "avd_vm_name" {
  description = "Name of the AVD VM"
  default     = "avd-vm"
}

variable "ctx_vm_name" {
  description = "Name of the Citrix VM"
  default     = "citrix-vm"
}

variable "avd_nsg_name" {
  description = "NSG name for AVD subnet"
  default     = "avd-nsg"
}

variable "ctx_nsg_name" {
  description = "NSG name for Citrix subnet"
  default     = "ctx-nsg"
}

# The subscription_id variable is used to specify the Azure Subscription ID where all resources will be provisioned.
variable "subscription_id" {
  description = "Azure Subscription ID used for deploying all resources in this Terraform configuration"
  type        = string
}

variable "vm_admin_username" {
  description = "Admin username for all VMs"
  type        = string
  default     = "azureuser"
}

variable "vm_admin_password" {
  description = "Admin password for all VMs"
  type        = string
  sensitive   = true
}

variable "spoke1_rt_name" {
  description = "Route table name for Spoke 1 (AVD)"
  default     = "spoke1-rt"
}

variable "spoke2_rt_name" {
  description = "Route table name for Spoke 2 (CTX)"
  default     = "spoke2-rt"
}

variable "firewall_private_ip" {
  description = "The private IP address of the Azure Firewall"
  type        = string
}