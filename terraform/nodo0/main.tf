variable "pm_api_token_id" {
  type        = string
  description = "API Token ID (e.g., terraform@pve!mytoken)"
}

variable "pm_api_token_secret" {
  type        = string
  sensitive   = true
  description = "API Token Secret"
}

variable "lxc_password" {
  type        = string
  sensitive   = true
  description = "Root password for the container"
}

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "~> 0.82.0"  # Or latest
    }
  }
}

provider "proxmox" {
  endpoint  = "https://200.200.200.130:8006/"  # Your Proxmox API endpoint
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"  # Combined format
  insecure  = true  # Skip TLS verification for self-signed certs
}
