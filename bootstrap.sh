#!/usr/bin/env bash

# Function to print step titles
function print_step() {
  echo "=== $1 ==="
}

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Initialize variables with environment variable defaults
local_sudo_password="${ANSIBLE_LOCAL_SUDO_PASSWORD:-}"
ssh_key="${ANSIBLE_SSH_KEY:-}"
remote_ip="${ANSIBLE_REMOTE_IP:-}"
remote_port="${ANSIBLE_REMOTE_PORT:-}"
remote_user="${ANSIBLE_REMOTE_USER:-}"
remote_sudo_password="${ANSIBLE_REMOTE_SUDO_PASSWORD:-}"
ssh_passphrase="${ANSIBLE_SSH_PASSPHRASE:-}"

print_step "Loading or prompting for variables"

# Prompt for parameters only if they are not already set
if [ -z "$local_sudo_password" ]; then
  read -sp "Enter local sudo password: " local_sudo_password
  echo
fi

if [ -z "$ssh_key" ]; then
  read -p "Enter SSH private key file location (default: ~/.ssh/id_ed25519): " input
  ssh_key=${input:-~/.ssh/id_ed25519}
fi

if [ -z "$ssh_passphrase" ]; then
  read -sp "Enter SSH passphrase (leave empty if none): " ssh_passphrase
  echo
fi

if [ -z "$remote_ip" ]; then
  read -p "Enter remote IP host: " remote_ip
fi

if [ -z "$remote_port" ]; then
  read -p "Enter remote SSH port: " remote_port
fi

if [ -z "$remote_user" ]; then
  read -p "Enter remote user: " remote_user
fi

if [ -z "$remote_sudo_password" ]; then
  read -sp "Enter remote sudo password: " remote_sudo_password
  echo
fi

print_step "Verifying local sudo password"
echo "$local_sudo_password" | sudo -S true
if [ $? -ne 0 ]; then
  echo "Incorrect local sudo password"
  exit 1
fi

print_step "Determining Linux distribution"
distro=$(lsb_release -is 2>/dev/null || ([ -f /etc/os-release ] && grep -oP '^ID=\K.*' /etc/os-release) || echo "Unknown")

print_step "Installing local packages"
if [ "$distro" == "Arch" ]; then
  packages_list=""

  if pacman -Q sshpass &>/dev/null; then
    echo "sshpass is already installed."
  else
    packages_list+=" sshpass"
  fi

  if pacman -Q ansible &>/dev/null; then
    echo "ansible is already installed."
  else
    packages_list+=" ansible"
  fi

  if [ "$packages_list" != "" ]; then
    echo "$local_sudo_password" | sudo -S pacman -Syuu --noconfirm $packages_list
  fi

elif [ "$distro" == "Debian" ] || [ "$distro" == "Ubuntu" ]; then
  packages_list=""

  if dpkg -s sshpass &>/dev/null; then
    echo "sshpass is already installed."
  else
    packages_list+=" sshpass"
  fi
  if dpkg -s ansible &>/dev/null; then
    echo "ansible is already installed."
  else
    packages_list+=" ansible"
  fi
  if [ "$packages_list" != "" ]; then
    echo "$local_sudo_password" | sudo -S apt update -y 
    echo "$local_sudo_password" | sudo -S apt upgrade -y 
    echo "$local_sudo_password" | sudo -S apt install -y $packages_list
  fi

elif [ "$distro" == "nixos" ]; then
  echo "NixOS detected - checking for required commands"
  missing_programs=""
  
  if ! command -v sshpass &>/dev/null; then
    missing_programs+=" sshpass"
  else
    echo "sshpass is available."
  fi
  
  if ! command -v ansible &>/dev/null; then
    missing_programs+=" ansible"
  else
    echo "ansible is available."
  fi
  
  if [ "$missing_programs" != "" ]; then
    echo "Missing required programs:$missing_programs"
    echo "Please install them using nix-env or add them to your system configuration."
    exit 1
  fi

else
  echo "Unsupported local distribution: $distro"
  exit 1
fi


print_step "Checking and installing community.general collection"
if ansible-galaxy collection list | grep -q "community.general"; then
  echo "community.general collection is already installed."
else
  echo "Installing community.general collection..."
  ansible-galaxy collection install community.general
fi

print_step "Detecting remote OS and installing Ansible"
echo "Connecting to $remote_user@$remote_ip:$remote_port"

# Detect remote OS
remote_distro=$(sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $remote_port $remote_user@$remote_ip "lsb_release -is 2>/dev/null || ([ -f /etc/arch-release ] && echo 'Arch') || ([ -f /etc/debian_version ] && echo 'Debian') || echo 'Unknown'")
echo "Remote OS detected: $remote_distro"

if [ "$remote_distro" == "Arch" ]; then
  echo "Installing packages on Arch remote system"
  sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $remote_port $remote_user@$remote_ip "echo '$remote_sudo_password' | sudo -S pacman -Syuu --noconfirm python python-pip git ansible"
  
elif [ "$remote_distro" == "Debian" ] || [ "$remote_distro" == "Ubuntu" ]; then
  echo "Installing packages on Debian-based remote system"
  sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $remote_port $remote_user@$remote_ip "echo '$remote_sudo_password' | sudo -S apt update -y && echo '$remote_sudo_password' | sudo -S apt upgrade -y && echo '$remote_sudo_password' | sudo -S apt install -y python3 python3-pip git ansible"
  
else
  echo "Unsupported remote distribution: $remote_distro"
  exit 1
fi

echo
echo "Installing community.general collection on remote"
sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $remote_port $remote_user@$remote_ip "ansible-galaxy collection install community.general"

echo
echo "Ansible installation completed successfully on remote host ($remote_distro)."
