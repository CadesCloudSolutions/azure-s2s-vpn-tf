# Configure the Azure provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Resource Group for all resources
resource "azurerm_resource_group" "hub" {
  name     = var.hub_rg_name
  location = var.location
}

# Virtual Network for the hub environment
resource "azurerm_virtual_network" "hub_vnet" {
  name                = "hub-vnet"
  address_space       = var.hub_vnet_address_space
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
}

# Subnet for VPN-Gateway
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.163.1.0/27"]
}

# Subnet for general hub resources
resource "azurerm_subnet" "hub_subnet" {
  name                 = "hub-subnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.163.0.0/24"]
}

# Subnet for Azure Firewall (not used by current VM)
resource "azurerm_subnet" "hub_firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = ["10.163.2.0/24"]
}

# Network Security Group for hub resources
resource "azurerm_network_security_group" "hub_nsg" {
  name                = "hub-nsg"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
}

# Associate NSG with hub subnet
resource "azurerm_subnet_network_security_group_association" "hub_subnet_nsg" {
  subnet_id                 = azurerm_subnet.hub_subnet.id
  network_security_group_id = azurerm_network_security_group.hub_nsg.id
}

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gw_pip" {
  name                = "vpn-gw-pip"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# VPN Gateway resource
resource "azurerm_virtual_network_gateway" "vpn_gw" {
  name                = "vpn-gw"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  enable_bgp          = false
  active_active       = false

  ip_configuration {
    name                          = "vpngw-ipconfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gw_pip.id
    subnet_id                     = azurerm_subnet.gateway_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Public IP for the hub VM
resource "azurerm_public_ip" "hubvm_ip" {
  name                = "hubvm-ip"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface for the hub VM
resource "azurerm_network_interface" "hubvm_nic" {
  name                = "hubvm-nic"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hub_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hubvm_ip.id
  }
}

# NSG rule to allow RDP access to the VM
resource "azurerm_network_security_rule" "rdp_rule" {
  name                        = "Allow-RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.hub.name
  network_security_group_name = azurerm_network_security_group.hub_nsg.name
}


resource "azurerm_network_security_rule" "allow_https_from_spoke" {
  name                        = "Allow-HTTPS-From-Spoke"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "445"
  source_address_prefix       = "10.125.0.0/24"
  destination_address_prefix  = "10.163.0.0/22"
  resource_group_name         = azurerm_resource_group.hub.name
  network_security_group_name = azurerm_network_security_group.hub_nsg.name
}

# NSG rule to allow ICMP traffic from on-premises network to the hub subnet or VM
# resource "azurerm_network_security_rule" "allow_icmp_from_onprem" {
#   name                        = "AllowICMPFromOnPrem"
#   priority                    = 110
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Icmp"
#   source_port_range           = "*"
#   destination_port_range      = "*"
#   source_address_prefix       = "192.168.170.0/24"    # On-premises subnet
#   destination_address_prefix  = "10.163.0.0/24"      # Use "10.63.0.4" for a single VM, or "VirtualNetwork" for subnet-wide
#   resource_group_name         = azurerm_resource_group.hub.name
#   network_security_group_name = azurerm_network_security_group.hub_nsg.name
# }

# Storage account for boot diagnostics (unique name with random suffix)
resource "random_string" "bootdiag_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "bootdiag" {
  name                     = "hubbootdiag${random_string.bootdiag_suffix.result}"
  resource_group_name      = azurerm_resource_group.hub.name
  location                 = azurerm_resource_group.hub.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "hub"
  }
}

# Windows Server 2019 Datacenter VM in the hub subnet
resource "azurerm_windows_virtual_machine" "hubvm" {
  name                = "hubvm"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  size                = "Standard_B1s"
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  network_interface_ids = [
    azurerm_network_interface.hubvm_nic.id
  ]

  os_disk {
    name                  = "hubvm-osdisk"
    caching               = "ReadWrite"
    storage_account_type  = "Premium_LRS"
  }

  # Enable boot diagnostics using the storage account above
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.bootdiag.primary_blob_endpoint
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  tags = {
    environment = "hub"
  }
}

# Local Network Gateway representing the on-premises network
resource "azurerm_local_network_gateway" "onprem_lngw" {
  name                = "onprem-lngw"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  gateway_address     = var.onprem_public_ip         # Public IP of on-prem server
  address_space       = [var.onprem_address_space]   # On-premises address space

  tags = {
    environment = "hub"
  }
}

resource "azurerm_virtual_network_gateway_connection" "vppn_local" {
  name                       = "vppn-local"
  location                   = azurerm_resource_group.hub.location
  resource_group_name        = azurerm_resource_group.hub.name

  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn_gw.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem_lngw.id

  type                       = "IPsec"
  shared_key                 = var.vpn_shared_key
  enable_bgp                 = false

  tags = {
    environment = "hub"
  }
}

# Route table for custom routing
resource "azurerm_route_table" "hub_rt" {
  name                = "hub-rt"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  tags = {
    environment = "hub"
  }
}

# Associate hub-rt route table with GatewaySubnet
resource "azurerm_subnet_route_table_association" "gateway_subnet_rt" {
  subnet_id      = azurerm_subnet.gateway_subnet.id
  route_table_id = azurerm_route_table.hub_rt.id
}

# Route for spoke1 in hub-rt
resource "azurerm_route" "hub_rt_spoke1_fw" {
  name                   = "spoke1"
  resource_group_name    = azurerm_resource_group.hub.name
  route_table_name       = azurerm_route_table.hub_rt.name
  address_prefix         = var.spoke1_address_prefix
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

# Route for onprem in hub-rt
resource "azurerm_route" "hub_rt_onprem_fw" {
  name                   = "onprem"
  resource_group_name    = azurerm_resource_group.hub.name
  route_table_name       = azurerm_route_table.hub_rt.name
  address_prefix         = var.onprem_address_space
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}

# # UDR for 169.254.0.0/16 to Virtual Network Gateway
# resource "azurerm_route" "to_vnet_gateway" {
# name                    = "to-vnet-gateway"
# resource_group_name     = azurerm_resource_group.hub.name
# route_table_name        = azurerm_route_table.hub_rt.name
# address_prefix          = "169.254.0.0/16"
# next_hop_type           = "VirtualNetworkGateway"
# }

# # Associate route table with hub-subnet
# resource "azurerm_subnet_route_table_association" "hub_subnet_rt" {
# subnet_id      = azurerm_subnet.hub_subnet.id
# route_table_id = azurerm_route_table.hub_rt.id
# }

# Resource Group for Spoke 1 (AVD)
resource "azurerm_resource_group" "spoke1_avd_rg" {
  name     = var.spoke1_rg_name
  location = var.location
}

resource "azurerm_virtual_network" "avd_vnet" {
  name                = "avd-vnet"
  address_space       = var.spoke1_vnet_address_space
  location            = azurerm_resource_group.spoke1_avd_rg.location
  resource_group_name = azurerm_resource_group.spoke1_avd_rg.name
}

# Resource Group for Spoke 2 (Ctx)
resource "azurerm_resource_group" "spoke2_ctx_rg" {
  name     = var.spoke2_rg_name
  location = var.location
}

resource "azurerm_virtual_network" "ctx_vnet" {
  name                = "ctx-vnet"
  address_space       = var.spoke2_vnet_address_space
  location            = azurerm_resource_group.spoke2_ctx_rg.location
  resource_group_name = azurerm_resource_group.spoke2_ctx_rg.name
}

# Peering from hub-vnet to avd-vnet (Spoke 1)
resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                      = var.hub_to_spoke1_peering_name
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.avd_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}


# Peering from avd-vnet (Spoke 1) to hub-vnet
resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                      = var.spoke1_to_hub_peering_name
  resource_group_name       = azurerm_resource_group.spoke1_avd_rg.name
  virtual_network_name      = azurerm_virtual_network.avd_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
}


# Peering from hub-vnet to ctx-vnet (Spoke 2)
resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                      = var.hub_to_spoke2_peering_name
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.ctx_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}


# Peering from ctx-vnet (Spoke 2) to hub-vnet
resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                      = var.spoke2_to_hub_peering_name
  resource_group_name       = azurerm_resource_group.spoke2_ctx_rg.name
  virtual_network_name      = azurerm_virtual_network.ctx_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub_vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
}


# Subnet for AVD VM in avd-vnet
resource "azurerm_subnet" "avd_subnet" {
  name                 = var.avd_subnet_name
  resource_group_name  = azurerm_resource_group.spoke1_avd_rg.name
  virtual_network_name = azurerm_virtual_network.avd_vnet.name
  address_prefixes     = [var.avd_subnet_prefix]
}

# NSG for AVD subnet
resource "azurerm_network_security_group" "avd_nsg" {
  name                = var.avd_nsg_name
  location            = azurerm_resource_group.spoke1_avd_rg.location
  resource_group_name = azurerm_resource_group.spoke1_avd_rg.name
}

# Associate NSG with AVD subnet
resource "azurerm_subnet_network_security_group_association" "avd_subnet_nsg" {
  subnet_id                 = azurerm_subnet.avd_subnet.id
  network_security_group_id = azurerm_network_security_group.avd_nsg.id
}

# RDP rule for AVD NSG
resource "azurerm_network_security_rule" "avd_rdp_rule" {
  name                        = "Allow-RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke1_avd_rg.name
  network_security_group_name = azurerm_network_security_group.avd_nsg.name
}

resource "azurerm_network_security_rule" "avd_outbound_to_hub" {
  name                        = "Allow-Outbound-To-Hub"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.125.0.0/24"
  destination_address_prefix  = "10.163.0.0/22"
  resource_group_name         = azurerm_resource_group.spoke1_avd_rg.name
  network_security_group_name = azurerm_network_security_group.avd_nsg.name
}


# Public IP for AVD VM
resource "azurerm_public_ip" "avd_vm_ip" {
  name                = "${var.avd_vm_name}-ip"
  location            = azurerm_resource_group.spoke1_avd_rg.location
  resource_group_name = azurerm_resource_group.spoke1_avd_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NIC for AVD VM
resource "azurerm_network_interface" "avd_vm_nic" {
  name                = "${var.avd_vm_name}-nic"
  location            = azurerm_resource_group.spoke1_avd_rg.location
  resource_group_name = azurerm_resource_group.spoke1_avd_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.avd_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.avd_vm_ip.id
  }
}

# Windows Server 2019 Datacenter VM in avd-vnet
resource "azurerm_windows_virtual_machine" "avd_vm" {
  name                = var.avd_vm_name
  location            = azurerm_resource_group.spoke1_avd_rg.location
  resource_group_name = azurerm_resource_group.spoke1_avd_rg.name
  size                = "Standard_B1s"
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  network_interface_ids = [
    azurerm_network_interface.avd_vm_nic.id
  ]

  os_disk {
    name                  = "${var.avd_vm_name}-osdisk"
    caching               = "ReadWrite"
    storage_account_type  = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  tags = {
    environment = "spoke1"
  }
}

# Subnet for Citrix VM in ctx-vnet
resource "azurerm_subnet" "ctx_subnet" {
  name                 = var.ctx_subnet_name
  resource_group_name  = azurerm_resource_group.spoke2_ctx_rg.name
  virtual_network_name = azurerm_virtual_network.ctx_vnet.name
  address_prefixes     = [var.ctx_subnet_prefix]
}

# NSG for Citrix subnet
resource "azurerm_network_security_group" "ctx_nsg" {
  name                = var.ctx_nsg_name
  location            = azurerm_resource_group.spoke2_ctx_rg.location
  resource_group_name = azurerm_resource_group.spoke2_ctx_rg.name
}

# Associate NSG with Citrix subnet
resource "azurerm_subnet_network_security_group_association" "ctx_subnet_nsg" {
  subnet_id                 = azurerm_subnet.ctx_subnet.id
  network_security_group_id = azurerm_network_security_group.ctx_nsg.id
}

# RDP rule for Citrix NSG
resource "azurerm_network_security_rule" "ctx_rdp_rule" {
  name                        = "Allow-RDP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke2_ctx_rg.name
  network_security_group_name = azurerm_network_security_group.ctx_nsg.name
}

# Public IP for Citrix VM
resource "azurerm_public_ip" "ctx_vm_ip" {
  name                = "${var.ctx_vm_name}-ip"
  location            = azurerm_resource_group.spoke2_ctx_rg.location
  resource_group_name = azurerm_resource_group.spoke2_ctx_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NIC for Citrix VM
resource "azurerm_network_interface" "ctx_vm_nic" {
  name                = "${var.ctx_vm_name}-nic"
  location            = azurerm_resource_group.spoke2_ctx_rg.location
  resource_group_name = azurerm_resource_group.spoke2_ctx_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ctx_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ctx_vm_ip.id
  }
}

# Windows Server 2019 Datacenter VM in ctx-vnet
resource "azurerm_windows_virtual_machine" "ctx_vm" {
  name                = var.ctx_vm_name
  location            = azurerm_resource_group.spoke2_ctx_rg.location
  resource_group_name = azurerm_resource_group.spoke2_ctx_rg.name
  size                = "Standard_B1s"
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  network_interface_ids = [
    azurerm_network_interface.ctx_vm_nic.id
  ]

  os_disk {
    name                  = "${var.ctx_vm_name}-osdisk"
    caching               = "ReadWrite"
    storage_account_type  = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  tags = {
    environment = "spoke2"
  }
}

# Azure firewall public IP
resource "azurerm_public_ip" "firewall_pip" {
  name                = "FW-PIP"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "hub_firewall" {
  name                = "ccs-firewall-prd"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  firewall_policy_id  = azurerm_firewall_policy.hub_fw_policy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }

  depends_on = [
    azurerm_public_ip.firewall_pip,
    azurerm_subnet.hub_firewall_subnet,
    azurerm_firewall_policy.hub_fw_policy
  ]
}

# Firewall Policy
resource "azurerm_firewall_policy" "hub_fw_policy" {
  name                = "ccs-fw-policy1"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
}

# Associate Firewall Policy with Azure Firewall
resource "azurerm_firewall_policy_rule_collection_group" "hub_fw_policy_group" {
  name               = "ccs-fw-policy1-group"
  firewall_policy_id = azurerm_firewall_policy.hub_fw_policy.id
  priority           = 100

  network_rule_collection {
    name     = "Allow-Spoke-to-Onprem"
    priority = 100
    action   = "Allow"
    rule {
      name                  = "ctx-spoke-to-onprem"
      source_addresses      = [var.spoke2_address_prefix]
      destination_addresses = [var.onprem_address_space]
      destination_ports     = ["*"]
      protocols             = ["Any"]
    }
  }

  network_rule_collection {
    name     = "Allow-Spoke1-to-Spoke2-Connectivity"
    priority = 110
    action   = "Allow"
    rule {
      name                  = "spoke1-to-spoke2"
      source_addresses      = [var.spoke1_address_prefix, var.spoke2_address_prefix, var.onprem_address_space]
      destination_addresses = [var.spoke2_address_prefix, var.onprem_address_space, var.spoke1_address_prefix]
      destination_ports     = ["*"]
      protocols             = ["Any"]
    }
  }

  network_rule_collection {
    name     = "Allow-Spoke2-to-Spoke1-Connectivity"
    priority = 120
    action   = "Allow"
    rule {
      name                  = "spoke2-to-spoke1"
      source_addresses      = [var.spoke2_address_prefix]
      destination_addresses = [var.spoke1_address_prefix]
      destination_ports     = ["*"]
      protocols             = ["Any"]
    }
  }

}



# Route table for Spoke 1 (AVD)
resource "azurerm_route_table" "spoke1_rt" {
  name                           = var.spoke1_rt_name
  location                       = azurerm_resource_group.spoke1_avd_rg.location
  resource_group_name            = azurerm_resource_group.spoke1_avd_rg.name
  bgp_route_propagation_enabled  = false  # disables gateway route propagation

  tags = {
    environment = "spoke1"
  }
}

# Associate Spoke 1 route table with the AVD subnet
resource "azurerm_subnet_route_table_association" "spoke1_subnet_rt" {
  subnet_id      = azurerm_subnet.avd_subnet.id
  route_table_id = azurerm_route_table.spoke1_rt.id
}

# Add a default route in Spoke 1 route table to send all traffic to Azure Firewall
resource "azurerm_route" "spoke1_default_fw" {
  name                   = "default-to-fw"
  resource_group_name    = azurerm_resource_group.spoke1_avd_rg.name
  route_table_name       = azurerm_route_table.spoke1_rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip  # Set in terraform.tfvars
}

# Route table for Spoke 2 (CTX)
resource "azurerm_route_table" "spoke2_rt" {
  name                           = var.spoke2_rt_name
  location                       = azurerm_resource_group.spoke2_ctx_rg.location
  resource_group_name            = azurerm_resource_group.spoke2_ctx_rg.name
  bgp_route_propagation_enabled  = false  # disables gateway route propagation

  tags = {
    environment = "spoke2"
  }
}

# Associate Spoke 2 route table with the CTX subnet
resource "azurerm_subnet_route_table_association" "spoke2_subnet_rt" {
  subnet_id      = azurerm_subnet.ctx_subnet.id
  route_table_id = azurerm_route_table.spoke2_rt.id
}

# Add a default route in Spoke 2 route table to send all traffic to Azure Firewall
resource "azurerm_route" "spoke2_default_fw" {
  name                   = "default-to-fw"
  resource_group_name    = azurerm_resource_group.spoke2_ctx_rg.name
  route_table_name       = azurerm_route_table.spoke2_rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip  # Set in terraform.tfvars
}






