#!/usr/bin/env bash



terraform init -upgrade
terraform plan -var-file=secrets.tfvars -target=proxmox_virtual_environment_container.dockeronlxcnodo0
terraform apply -var-file=secrets.tfvars -target=proxmox_virtual_environment_container.dockeronlxcnodo0 --auto-approve
terraform apply -var-file=secrets.tfvars -target=proxmox_virtual_environment_container.dockernvidialxcnodo0 --auto-approve
#terraform apply --auto-approve -var-file=secrets.tfvars
#terraform destroy -target=proxmox_virtual_environment_container.dockeronlxcnodo0