environment_name      = "staging"
deployment_region     = "centralindia"
network_cidr          = "10.7.0.0/16"
vm_size               = "Standard_B2ats_v2"
assigned_public_ip_id = null

# WARNING: This opens SSH from anywhere. Restrict for real environments.
allowed_ssh_cidrs = ["0.0.0.0/0"]

admin_username       = "azureuser"
admin_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDreplace-with-your-real-public-key"

tags = {
  environment = "staging"
  managed_by  = "terraform"
  workload    = "ministry"
}
