resource "azurerm_resource_group" "compute_rg" {
  name     = "rg-compute-${var.environment_name}"
  location = var.deployment_region
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "nic-${var.environment_name}"
  location            = azurerm_resource_group.compute_rg.location
  resource_group_name = azurerm_resource_group.compute_rg.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assigned_public_ip_id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "edge-vm-${var.environment_name}"
  location            = azurerm_resource_group.compute_rg.location
  resource_group_name = azurerm_resource_group.compute_rg.name
  size                = var.vm_size
  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${var.environment_name}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  tags = var.tags
}
