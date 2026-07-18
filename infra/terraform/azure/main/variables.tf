variable "environment_name" {
  description = "Environment name used for resource naming"
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment_name)
    error_message = "environment_name must be either 'staging' or 'prod'."
  }
}

variable "deployment_region" {
  description = "Azure region for staging resources"
  type        = string
}

variable "network_cidr" {
  description = "CIDR block for the staging virtual network"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.network_cidr))
    error_message = "network_cidr must be a valid IPv4 CIDR block (for example, 10.10.0.0/16)."
  }
}

variable "dns_servers" {
  description = "Optional DNS servers for the staging VNet; null uses module defaults"
  type        = list(string)
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "CIDR ranges allowed to access SSH (TCP/22) on the staging subnet"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "assigned_public_ip_id" {
  description = "Optional existing public IP resource ID for the VM NIC; null uses network module public IP"
  type        = string
  default     = null
}

variable "vm_size" {
  description = "VM SKU for the staging Linux virtual machine"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Administrator username for the staging Linux VM"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key used for Linux VM admin access"
  type        = string
}

variable "os_disk_type" {
  description = "Managed disk SKU for the VM OS disk"
  type        = string
  default     = "Standard_LRS"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GiB for the VM"
  type        = number
  default     = 30
}

variable "image_publisher" {
  description = "Publisher of the VM image"
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "Offer of the VM image"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "SKU of the VM image"
  type        = string
  default     = "22_04-lts"
}

variable "image_version" {
  description = "Version of the VM image"
  type        = string
  default     = "latest"
}

variable "tags" {
  description = "Tags applied to all staging resources"
  type        = map(string)
  default = {
    environment = "staging"
    managed_by  = "terraform"
  }
}
