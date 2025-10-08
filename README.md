# GCP Server Infrastructure (Terraform)

This repository contains the Terraform configuration for provisioning the foundational infrastructure on Google Cloud Platform.

It is responsible for creating:
* A static IP address.
* A Google Compute Engine (GCE) VM instance to act as the application server.
* A dedicated service account for the VM with appropriate permissions.
* A private Docker repository in Google Artifact Registry.
* Firewall rules to allow HTTP and HTTPS traffic.

## Initial Setup

1.  **Authenticate with GCP**: Make sure your local machine is authenticated with the `gcloud` CLI and has permission to create resources in your project.
    ```bash
    gcloud auth application-default login
    ```
2.  **Configure Project**: Open `variables.tf` and ensure the `gcp_project_id` default value is set to your correct GCP Project ID.
3.  **SSH Key**: This configuration assumes you have an SSH key pair for connecting to the server at `~/.ssh/id_ed25519_gcp` and `~/.ssh/id_ed25519_gcp.pub`.

## Usage

This configuration should typically only be applied once for the initial setup or when foundational infrastructure changes are needed.

1.  **Initialize Terraform**:
    ```bash
    terraform init
    ```
2.  **Apply Configuration**:
    ```bash
    terraform apply
    ```
    Terraform will show you a plan of the resources to be created. Type `yes` to approve.

## Outputs

After a successful run, Terraform will output the following values:
* `server_ip`: The public IP address of the newly created server.
* `artifact_registry_repository_url`: The URL for your private Docker repository.