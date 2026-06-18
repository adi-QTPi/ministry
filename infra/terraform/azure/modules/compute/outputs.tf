output "resource_group_name" {
  description = "Name of the resource group containing compute resources"
  value       = azurerm_resource_group.compute_rg.name
}

output "virtual_machine_id" {
  description = "Resource ID of the Linux virtual machine"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "virtual_machine_name" {
  description = "Name of the Linux virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "network_interface_id" {
  description = "Resource ID of the VM network interface"
  value       = azurerm_network_interface.vm_nic.id
}

output "private_ip_address" {
  description = "Primary private IP address assigned to the VM NIC"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "public_ip_id" {
  description = "Public IP resource ID attached to the VM NIC"
  value       = var.assigned_public_ip_id
}
