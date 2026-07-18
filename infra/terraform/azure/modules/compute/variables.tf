variable "environment_name" {
  type        = string
  description = "The deployment target environment name (e.g., staging, prod). Used to enforce resource naming conventions uniformly."

  validation {
    condition     = contains(["staging", "prod"], var.environment_name)
    error_message = "The environment_name variable must be exactly either 'staging' or 'prod'."
  }
}

variable "deployment_region" {
  description = "The Azure region code"
  type        = string
}

variable "vm_size" {
  type        = string
  description = "The hardware SKU defining the CPU, memory, and IOPS capabilities of the underlying virtual machine."

  validation {
    condition     = length(trimspace(var.vm_size)) > 0
    error_message = "vm_size must not be empty (for example, Standard_B2s)."
  }
}

variable "subnet_id" {
  type        = string
  description = "The fully qualified Azure Resource ID of the target virtual network subnet where the network interface card will be attached."

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_id))
    error_message = "The provided subnet_id must be a valid, fully formed Azure Resource ID string."
  }
}

variable "assigned_public_ip_id" {
  type        = string
  description = "Optional existing public IP resource ID to attach to the VM NIC."
  default     = null

  validation {
    condition = var.assigned_public_ip_id == null || can(regex(
      "^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/publicIPAddresses/[^/]+$",
      var.assigned_public_ip_id
    ))
    error_message = "assigned_public_ip_id must be null or a valid Azure Public IP resource ID."
  }
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether to create and attach a public IP to the VM network interface."
  default     = false
}

variable "public_ip_allocation_method" {
  type        = string
  description = "Allocation method for the VM public IP when assign_public_ip is enabled."
  default     = "Static"

  validation {
    condition     = contains(["Static", "Dynamic"], var.public_ip_allocation_method)
    error_message = "public_ip_allocation_method must be either 'Static' or 'Dynamic'."
  }
}

variable "public_ip_sku" {
  type        = string
  description = "SKU of the VM public IP when assign_public_ip is enabled."
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard"], var.public_ip_sku)
    error_message = "public_ip_sku must be either 'Basic' or 'Standard'."
  }
}

variable "admin_username" {
  type        = string
  description = "Local administrator username for the Linux VM."
  default     = "azureuser"

  validation {
    condition     = length(trimspace(var.admin_username)) > 0
    error_message = "admin_username must not be empty."
  }
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key used for administrator access to the Linux VM."

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp(256|384|521))\\s+", trimspace(var.admin_ssh_public_key)))
    error_message = "admin_ssh_public_key must be a valid SSH public key string."
  }
}

variable "os_disk_type" {
  type        = string
  description = "Managed disk storage account type for the VM OS disk."
  default     = "Standard_LRS"

  validation {
    condition = contains([
      "Standard_LRS",
      "StandardSSD_LRS",
      "Premium_LRS",
      "StandardSSD_ZRS",
      "Premium_ZRS"
    ], var.os_disk_type)
    error_message = "os_disk_type must be a valid Azure managed disk SKU."
  }
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size for the VM in GiB."
  default     = 30

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4095
    error_message = "os_disk_size_gb must be between 30 and 4095 GiB."
  }
}

variable "image_publisher" {
  type        = string
  description = "Publisher of the VM image."
  default     = "Canonical"
}

variable "image_offer" {
  type        = string
  description = "Offer of the VM image."
  default     = "ubuntu-24_04-lts"
}

variable "image_sku" {
  type        = string
  description = "SKU of the VM image."
  default     = "server"
}

variable "image_version" {
  type        = string
  description = "Version of the VM image."
  default     = "latest"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to compute resources."
  default     = {}
}
