locals {
  default_dns_servers = ["1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4"]
}

resource "azurerm_resource_group" "network_rg" {
  name     = "rg-network-${var.environment_name}"
  location = var.deployment_region
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.environment_name}"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
  address_space       = [var.network_cidr]
  dns_servers         = var.dns_servers == null ? local.default_dns_servers : var.dns_servers
}

resource "azurerm_subnet" "default" {
  name                 = "default-${var.environment_name}"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.network_cidr, 8, 0)]
}

resource "azurerm_network_security_group" "default_subnet_nsg" {
  name                = "nsg-default-${var.environment_name}"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
}

resource "azurerm_network_security_rule" "allow_ssh" {
  count = length(var.allowed_ssh_cidrs) > 0 ? 1 : 0

  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ssh_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network_rg.name
  network_security_group_name = azurerm_network_security_group.default_subnet_nsg.name
}

resource "azurerm_network_security_rule" "allow_http" {
  name                        = "allow-http"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network_rg.name
  network_security_group_name = azurerm_network_security_group.default_subnet_nsg.name
}

resource "azurerm_network_security_rule" "allow_https" {
  name                        = "allow-https"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network_rg.name
  network_security_group_name = azurerm_network_security_group.default_subnet_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "default" {
  subnet_id                 = azurerm_subnet.default.id
  network_security_group_id = azurerm_network_security_group.default_subnet_nsg.id
}

resource "azurerm_public_ip" "vm_pip" {
  name                = "pip-${var.environment_name}"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
