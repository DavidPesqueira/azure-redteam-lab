variable "location" {
  description = "Azure region to deploy resources in"
  type        = string
  default     = "eastus"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "labadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for admin access"
  type        = string
}
