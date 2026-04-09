#!/bin/bash

# Deploy script for Terraform Ansible CodeBuild Template

set -e

echo "Initializing Terraform..."
cd terraform
terraform init

echo "Planning Terraform changes..."
terraform plan

echo "Applying Terraform changes..."
terraform apply -auto-approve

echo "Running Ansible playbook..."
cd ../ansible
ansible-playbook -i inventory/hosts playbooks/main.yml

echo "Deployment complete!"