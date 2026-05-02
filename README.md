# 🏗️ Weather Infrastructure (IaC)

This repository contains the **Terraform** configuration required to provision the entire cloud environment for the Weather Application.

## 🚀 Provisioned Resources
* **Networking:** Custom VPC, Public Subnets, and Security Groups.
* **Compute:** AWS EC2 instance running K3s (Lightweight Kubernetes).
* **Storage:** AWS DynamoDB table for weather data persistence.
* **Security:** IAM Roles and Policies for secure service-to-service communication.

## 🛠️ Tech Stack
* **IaC Tool:** Terraform
* **Cloud Provider:** AWS
* **Platform:** Kubernetes (K3s)

## 🚀 Getting Started

### Prerequisites
* Terraform CLI installed.
* AWS CLI configured with appropriate permissions.

### Deployment
1. Initialize Terraform:
   ```bash
   terraform init
Review Plan:

Bash
terraform plan
Apply Infrastructure:

Bash
terraform apply --auto-approve
🛡️ Security
Security Groups are configured with the Principle of Least Privilege:

Port 22: SSH Access (Restricted).

Port 6443: Kubernetes API Access.

Port 30001: Frontend LoadBalancer access.

Maintained by Moti Levi