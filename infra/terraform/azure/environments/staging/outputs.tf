output "network_resource_group_name" {
  description = "Resource group name for staging network resources"
  value       = module.base_network.resource_group_name
}

output "virtual_network_id" {
  description = "Virtual network ID for staging"
  value       = module.base_network.virtual_network_id
}

output "default_subnet_id" {
  description = "Default subnet ID used by staging compute"
  value       = module.base_network.default_subnet_id
}

output "default_subnet_nsg_id" {
  description = "NSG ID associated with the default staging subnet"
  value       = module.base_network.default_subnet_nsg_id
}

output "compute_resource_group_name" {
  description = "Resource group name for staging compute resources"
  value       = module.base_compute.resource_group_name
}

output "virtual_machine_id" {
  description = "Staging Linux VM resource ID"
  value       = module.base_compute.virtual_machine_id
}

output "virtual_machine_name" {
  description = "Staging Linux VM name"
  value       = module.base_compute.virtual_machine_name
}

output "network_interface_id" {
  description = "Staging VM NIC resource ID"
  value       = module.base_compute.network_interface_id
}

output "virtual_machine_private_ip" {
  description = "Primary private IP assigned to the staging VM"
  value       = module.base_compute.private_ip_address
}

output "virtual_machine_public_ip_id" {
  description = "Public IP resource ID attached to the staging VM NIC"
  value       = module.base_compute.public_ip_id
}

output "network_static_public_ip_id" {
  description = "Static public IP resource ID created by the network module"
  value       = module.base_network.static_public_ip_id
}

output "network_static_public_ip_address" {
  description = "Static public IPv4 address created by the network module"
  value       = module.base_network.static_public_ip_address
}
