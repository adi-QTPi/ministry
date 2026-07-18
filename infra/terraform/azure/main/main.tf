module "base_network" {
  source = "../modules/network"

  environment_name  = var.environment_name
  deployment_region = var.deployment_region
  network_cidr      = var.network_cidr
  dns_servers       = var.dns_servers
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "base_compute" {
  source = "../modules/compute"

  environment_name      = var.environment_name
  deployment_region     = var.deployment_region
  subnet_id             = module.base_network.default_subnet_id
  vm_size               = var.vm_size
  admin_username        = var.admin_username
  admin_ssh_public_key  = var.admin_ssh_public_key
  os_disk_type          = var.os_disk_type
  os_disk_size_gb       = var.os_disk_size_gb
  image_publisher       = var.image_publisher
  image_offer           = var.image_offer
  image_sku             = var.image_sku
  image_version         = var.image_version
  tags                  = var.tags
  assigned_public_ip_id = var.assigned_public_ip_id == null ? module.base_network.static_public_ip_id : var.assigned_public_ip_id
}
