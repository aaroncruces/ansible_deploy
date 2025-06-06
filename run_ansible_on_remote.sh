#!/bin/bash

# Path to the inventory file
INVENTORY="inventory/hosts.yml"

# Extract the passphrase using sed
PASSPHRASE=$(sed -n '/ansible_ssh_passphrase:/s/.*: //p' "$INVENTORY")

# Check if passphrase was successfully retrieved
if [ -z "$PASSPHRASE" ]; then
  echo "Error: Could not retrieve passphrase from inventory."
  exit 1
fi

# Extract the SSH private key file path using sed
SSH_KEY=$(sed -n '/ansible_ssh_private_key_file:/s/.*: //p' "$INVENTORY")

# Check if SSH key path was successfully retrieved
if [ -z "$SSH_KEY" ]; then
  echo "Error: Could not retrieve SSH key path from inventory."
  exit 1
fi

# Start ssh-agent
eval $(ssh-agent -s)

# Add the SSH key with the passphrase
echo "$PASSPHRASE" | ssh-add "$SSH_KEY"

# Check if the key was added successfully
if [ $? -ne 0 ]; then
  echo "Error: Failed to add SSH key to agent."
  exit 1
fi

# Run the Ansible playbook
ansible-playbook -i "$INVENTORY" playbook.yml

# Optionally, kill the ssh-agent after the playbook run
# ssh-agent -k