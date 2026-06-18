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

variable "network_cidr" {
  description = "The CIDR block for the entire VNet"
  type        = string
}

variable "dns_servers" {
  description = "Optional custom DNS servers for the VNet; null uses module defaults"
  type        = list(string)
  default     = null

  validation {
    condition     = var.dns_servers == null || alltrue([for server in var.dns_servers : can(cidrhost("${server}/32", 0))])
    error_message = "Each dns_servers entry must be a valid IPv4 address."
  }
}

variable "allowed_ssh_cidrs" {
  description = "CIDR ranges allowed to access SSH (TCP/22) on the default subnet"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.allowed_ssh_cidrs : can(cidrnetmask(cidr))])
    error_message = "Each allowed_ssh_cidrs entry must be a valid IPv4 CIDR block."
  }
}
