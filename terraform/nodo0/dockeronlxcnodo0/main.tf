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

resource "proxmox_virtual_environment_container" "terraexamplelxc" {
  node_name   = "nodo0"
  vm_id       = 2001  # Optional; auto-assigned if omitted
  description = "Managed by Terraform"
  started     = true
  unprivileged = true

  initialization {
    hostname = "terraexamplelxc"
    user_account {
      password = var.lxc_password
    }
    ip_config {
      ipv4 {
        address = "200.200.200.142/24"  # Static IP in CIDR; for DHCP, change to "dhcp"
        gateway = "200.200.200.1"       # Optional: Your gateway IP (comment out or remove for DHCP)
      }
    }
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 16384  # 16 GB RAM (in MB)
    swap      = 1024   # 1 GB swap (in MB)
  }

  disk {
    datastore_id = "local"
    size         = 32  # 32 GB disk
  }

  features {
    nesting = true
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"  # Your bridge (adjust if needed)
    enabled = true
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    type             = "debian"
  }
}