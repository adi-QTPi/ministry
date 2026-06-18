output "resource_group_name" {
  description = "Name of the resource group containing networking resources"
  value       = azurerm_resource_group.network_rg.name
}

output "virtual_network_id" {
  description = "Resource ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "default_subnet_id" {
  description = "Resource ID of the default subnet"
  value       = azurerm_subnet.default.id
}

output "default_subnet_nsg_id" {
  description = "Resource ID of the NSG associated with the default subnet"
  value       = azurerm_network_security_group.default_subnet_nsg.id
}

output "static_public_ip_id" {
  description = "The ID of the static public IP to be used by the compute tier"
  value       = azurerm_public_ip.vm_pip.id
}

output "static_public_ip_address" {
  description = "The IPv4 address assigned to the static public IP"
  value       = azurerm_public_ip.vm_pip.ip_address
}
