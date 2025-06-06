#!/bin/bash

# Function to print step titles
function print_step() {
  echo "=== $1 ==="
}

# Create the inventory directory if it doesn't exist
mkdir -pv inventory

# Initialize variables
local_sudo_password=""
ssh_key=""
remote_ip=""
remote_port=""
remote_user=""
remote_sudo_password=""
python_interpreter=""
ssh_passphrase=""

# Extract values from existing inventory/hosts.yml if it exists
if [ -f "inventory/hosts.yml" ]; then
  local_sudo_password=$(awk '/^    local:/ {flag=1; next} /^    [a-zA-Z0-9_-]+:/ {flag=0} flag && $1 == "ansible_become_password:" {print $2}' inventory/hosts.yml)
  remote_ip=$(awk '/^    remote:/ {flag=1; next} /^    [a-zA-Z0-9_-]+:/ {flag=0} flag && $1 == "ansible_host:" {print $2}' inventory/hosts.yml)
  remote_port=$(awk '/^    remote:/ {flag=1; next} /^    [a-zA-Z0-9_-]+:/ {flag=0} flag && $1 == "ansible_port:" {print $2}' inventory/hosts.yml)
  remote_user=$(awk '/^    remote:/ {flag=1; next} /^    [a-zA-Z0-9_-]+:/ {flag=0} flag && $1 == "ansible_user:" {print $2}' inventory/hosts.yml)
  remote_sudo_password=$(awk '/^    remote:/ {flag=1; next} /^    [a-zA-Z0-9_-]+:/ {flag=0} flag && $1 == "ansible_become_password:" {print $2}' inventory/hosts.yml)
  ssh_key=$(awk '/^    remote:/ {flag=1; next} /^    [a-zA-Z0-9_-]+:/ {flag=0} flag && $1 == "ansible_ssh_private_key_file:" {print $2}' inventory/hosts.yml)
  python_interpreter=$(awk '/^    remote:/ {flag=1; next} /^    [a-zA-Z0-9_-]+:/ {flag=0} flag && $1 == "ansible_python_interpreter:" {print $2}' inventory/hosts.yml)
  ssh_passphrase=$(awk '/^    remote:/ {flag=1; next} /^    [a-zA-Z0-9_-]+:/ {flag=0} flag && $1 == "ansible_ssh_passphrase:" {print $2}' inventory/hosts.yml)
fi

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

if [ -z "$python_interpreter" ]; then
  read -p "Enter Python interpreter path (default: /usr/bin/python3.11): " input
  python_interpreter=${input:-/usr/bin/python3.11}
fi

print_step "Verifying local sudo password"
echo "$local_sudo_password" | sudo -S true
if [ $? -ne 0 ]; then
  echo "Incorrect local sudo password"
  exit 1
fi

print_step "Determining Linux distribution"
distro=$(lsb_release -is)

print_step "Checking and installing required packages"
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

elif [ "$distro" == "Debian" ]; then
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
    echo "$local_sudo_password" | sudo -S apt install -y packages_list
  fi

else
  echo "Unsupported local distribution: $distro"
  exit 1
fi

# Generate inventory/hosts.yml with the final variables
cat >inventory/hosts.yml <<EOL
all:
  hosts:
    local:
      ansible_become: true
      ansible_become_password: ${local_sudo_password}
    remote:
      ansible_host: ${remote_ip}
      ansible_port: ${remote_port}
      ansible_user: ${remote_user}
      ansible_become: true
      ansible_become_password: ${remote_sudo_password}
      ansible_ssh_private_key_file: ${ssh_key}
      ansible_python_interpreter: ${python_interpreter}
      ansible_ssh_passphrase: ${ssh_passphrase}
EOL

print_step "Checking and installing community.general collection"
if ansible-galaxy collection list | grep -q "community.general"; then
  echo "community.general collection is already installed."
else
  echo "Installing community.general collection..."
  ansible-galaxy collection install community.general
fi

print_step "Verifying remote connection"

# Store original IP and port in case they need to be used for connection
old_ip="$remote_ip"
old_port="$remote_port"

# Flags to track if updates are needed
update_ssh_creds_needed=false

# Check if remote IP is reachable
if ! ping -c 1 "$remote_ip" &>/dev/null; then
  echo "Remote IP $remote_ip is not reachable."
  read -p "Enter the current IP: " old_ip
  update_ssh_creds_needed=true
  ssh_new_ip_needed=true
fi

if ! ping -c 1 "$old_ip" &>/dev/null; then
  echo "Remote IP $old_ip is not reachable."
  exit 1
fi

# Check if SSH port is open using /dev/tcp
if ! timeout 1 bash -c "echo > /dev/tcp/$old_ip/$remote_port" &>/dev/null; then
  echo "SSH port $remote_port is not open on $old_ip."
  read -p "Enter the current port: " old_port
  update_ssh_creds_needed=true
  ssh_new_port_needed=true
fi

# Check if SSH port is open using /dev/tcp
if ! timeout 1 bash -c "echo > /dev/tcp/$old_ip/$old_port" &>/dev/null; then
  echo "SSH port $old_port is not open on $old_ip."
  exit 1
fi

# Attempt to connect using SSH key
if ! sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $old_port $remote_user@$old_ip "exit" &>/dev/null; then
  echo "Connection with SSH public key authentication failed."
  update_ssh_creds_needed=true
  ssh_new_pubkey_needed=true
fi

# If any check failed, connect with old credentials and update configurations
if [ "$update_ssh_creds_needed" = true ]; then
  if [ "$ssh_new_pubkey_needed" = true ]; then
    echo "Update ssh to public key"
    read -sp "Enter the current password for $remote_user@$old_ip (port $old_port): " old_password
    # Test connection with old credentials
    echo "Testing new credentials with current password"
    if ! sshpass -p "$old_password" ssh -p "$old_port" "$remote_user@$old_ip" "exit" &>/dev/null; then
      echo "Failed to connect with provided credentials."
      exit 1
    fi
    # Set up key-based authentication
    echo "Adding pubkey with ssh copy id"
    sshpass -p "$old_password" ssh-copy-id -i "$ssh_key" -p "$old_port" "$remote_user@$old_ip"

    # Verify SSH key authentication
    echo "Testing new public key and passphrase"
    if sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $old_port $remote_user@$old_ip "exit" &>/dev/null; then
      echo "SSH key authentication set up successfully."
    else
      echo "The added credentials don't work"
      exit 1
    fi
  fi


  # Update SSH port if needed
  if [ "$ssh_new_port_needed" = true ]; then
    echo "Updating SSH port in /etc/ssh/sshd_config to $remote_port"
    sshpass -Ppassphrase -f <(printf '%s\n' "$ssh_passphrase") ssh -p "$old_port" "$remote_user@$old_ip" \
      "echo '$remote_sudo_password' | sudo -S bash -c '
      # Replace any Port line (commented or not) with the new port
      sed -i \"s/^#*Port .*/Port $remote_port/\" /etc/ssh/sshd_config;
      # If no uncommented Port line exists, append one
      if ! grep -q \"^Port \" /etc/ssh/sshd_config; then
        echo \"Port $remote_port\" >> /etc/ssh/sshd_config;
      fi
    '"
  fi

  interface_name=$(sshpass -Ppassphrase -f <(printf '%s\n' "$ssh_passphrase") ssh -p "$old_port" "$remote_user@$old_ip" "
    server_ip=\$(echo \$SSH_CONNECTION | awk '{print \$3}')
    ip -o addr show | grep -w \"\$server_ip\" | awk '{print \$2}' | head -n1
  ")

  netmask="255.255.255.0"
  gateway=$(ip route | grep default | awk '{print $3}' | head -n 1)
  if [ -z "$gateway" ]; then
    echo "No default gateway found."
    exit 1
  fi

  # Update IP address if needed
  if [ "$ssh_new_ip_needed" = true ]; then
    echo "Updating IP in /etc/network/interfaces for interface $interface_name to $remote_ip"
    sshpass -Ppassphrase -f <(printf '%s\n' "$ssh_passphrase") ssh -p "$old_port" "$remote_user@$old_ip" \
      "echo '$remote_sudo_password' | sudo -S bash -c '
      if grep -q \"iface $interface_name inet static\" /etc/network/interfaces; then
        # If static, just update the address line
        sed -i \"s/^address .*/address $remote_ip/\" /etc/network/interfaces
      elif grep -q \"iface $interface_name inet dhcp\" /etc/network/interfaces; then
        # If DHCP, switch to static and add address, netmask, and gateway
        sed -i \"s/iface $interface_name inet dhcp/iface $interface_name inet static\\naddress $remote_ip\\nnetmask $netmask\\ngateway $gateway/\" /etc/network/interfaces
      else
        echo \"Interface $interface_name not found or not configured for inet; please check /etc/network/interfaces\"
      fi
    '"
  fi
  echo
  echo "------Configuration updates completed. Rebooting remote. Re-try the script after reset---------"
  sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -p "$old_port" "$remote_user@$old_ip" \
    "echo '$remote_sudo_password' | sudo -S reboot"
  exit 0
fi


print_step "Installing deps in remote"
echo "apt update"
sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $remote_port $remote_user@$remote_ip "echo '$remote_sudo_password' | sudo -S apt update -y"
echo
echo "apt upgrade"
sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $remote_port $remote_user@$remote_ip "echo '$remote_sudo_password' | sudo -S apt upgrade -y"
echo
echo "apt install packages"
sshpass -Ppassphrase -f <(printf '%s\n' $ssh_passphrase) ssh -i $ssh_key -o PreferredAuthentications=publickey -p $remote_port $remote_user@$remote_ip "echo '$remote_sudo_password' | sudo -S apt upgrade -y python3 python3-pip python3-full sshpass git ansible stow"
echo
echo "Bootstrap process completed successfully."
