resource "proxmox_virtual_environment_container" "docker_nvidia_lxc" {
  node_name   = "nodo0"
  vm_id       = 2002  # Unique ID; adjust to avoid conflicts
  description = "LXC for Docker with NVIDIA Container Toolkit"
  started     = true
  unprivileged = true  # Unprivileged for security; works with device passthrough

  initialization {
    hostname = "docker-nvidia-lxc"
    user_account {
      password = var.lxc_password
    }
    ip_config {
      ipv4 {
        address = "200.200.200.143/24"  # Adjust IP; use "dhcp" for dynamic
        gateway = "200.200.200.1"
      }
    }
  }

  cpu {
    cores = 1  # Adjust as needed
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
    nesting = true  # Required for Docker inside LXC
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"  # Your bridge
    enabled = true
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
    type             = "debian"
  }

  # Device passthrough for NVIDIA GPUs (adjust paths based on ls /dev/nvidia* on host)
  device_passthrough {
    path       = "/dev/nvidia0"
    mode       = "0666"  # rw for all; adjust for security (e.g., "0660" if using video group)
    uid        = 0       # root user on host
    gid        = 0       # root group on host (or video/render gid like 44/106 if applicable)
    deny_write = false   # Allow writes
  }

  device_passthrough {
    path       = "/dev/nvidiactl"
    mode       = "0666"
    uid        = 0
    gid        = 0
    deny_write = false
  }

  device_passthrough {
    path       = "/dev/nvidia-uvm"
    mode       = "0666"
    uid        = 0
    gid        = 0
    deny_write = false
  }

  device_passthrough {
    path       = "/dev/nvidia-uvm-tools"
    mode       = "0666"
    uid        = 0
    gid        = 0
    deny_write = false
  }

  device_passthrough {
    path       = "/dev/nvidia-modeset"
    mode       = "0666"
    uid        = 0
    gid        = 0
    deny_write = false
  }
}