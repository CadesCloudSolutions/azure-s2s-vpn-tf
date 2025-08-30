# azure-s2s-vpn-tf
Azure Site to Site VPN connection to On-Prem Site using a VPN Gateway Connection and hub and spoke networking architecture.
# Azure Site-to-Site (S2S) VPN Setup

This repository contains Terraform code to deploy a hub-and-spoke network topology in Azure with a Site-to-Site VPN connection.

## Features

- Hub and spoke VNets
- VPN Gateway for Site-to-Site connectivity
- Azure Firewall subnet (ready for Azure Firewall deployment)
- Spoke VNet peering with gateway transit
- Secure NSG rules for RDP, SMB, and custom traffic
- Spoke VMs (AVD and Citrix) for private connectivity
- Boot diagnostics for VMs



<img width="1093" height="682" alt="image" src="https://github.com/user-attachments/assets/d3096a4a-b0ed-43d5-888d-e8639aea998d" />

