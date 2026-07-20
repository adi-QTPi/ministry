output "public_ip" {
  description = "Public IP address of the staging VM"
  value       = module.base_network.static_public_ip_address
  sensitive   = true
}
