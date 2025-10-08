# GCP Server Infrastructure (Terraform)

This repository contains the Terraform configuration for provisioning the foundational infrastructure on Google Cloud Platform. This setup is the bedrock of the entire application hosting environment and is typically only run once or when making significant changes to the underlying infrastructure.

## Architecture Overview

This Terraform configuration creates the core, non-application-specific resources required to run the containerized application platform. It is the first step in setting up the environment and provides the server and services that the Ansible configuration will later manage.

## Resources Created

This configuration will provision the following resources in your GCP project:

* **A Google Compute Engine (GCE) VM instance (`e2-micro`)**: This serves as the main application server where all Docker containers will run.
* **A static public IP address**: This ensures the server's IP address does not change, which is crucial for DNS configuration.
* **A private Docker repository in Google Artifact Registry**: This provides a secure, private location to store and manage your application's Docker images.
* **Dedicated Service Accounts**:
    * `app-server-identity`: A dedicated service account for the VM instance with the necessary permissions to pull images from the private Artifact Registry.
* **Firewall Rules**: A rule named `allow-http-https` that opens ports 80 and 443 to allow public web traffic to the server.

---

## Initial Setup

1.  **Authenticate with GCP**: Before running Terraform, ensure your local machine is authenticated with the `gcloud` CLI and has the necessary permissions to create resources in your project.
    ```bash
    gcloud auth application-default login
    ```
2.  **Configure Project**: Open `variables.tf` and ensure the `gcp_project_id` default value is set to your correct GCP Project ID. The default is currently set to `matthewc`.
3.  **SSH Key**: This configuration requires an SSH key pair to be present on your local machine at `~/.ssh/id_ed25519_gcp` (private key) and `~/.ssh/id_ed25519_gcp.pub` (public key) to grant you SSH access to the server.

## Usage

This configuration should be applied from your local machine.

1.  **Initialize Terraform**:
    ```bash
    terraform init
    ```
2.  **Apply Configuration**:
    ```bash
    terraform apply
    ```
    Terraform will show you a plan of the resources to be created. Review the plan and type `yes` to approve and begin provisioning.

## Outputs

After a successful run, Terraform will output the following values, which are needed for subsequent configuration steps:

* **`server_ip`**: The public IP address of the newly created server. This is the value you will use for your DNS `A` records.
* **`artifact_registry_repository_url`**: The URL for your private Docker repository. This is used in your application's CI/CD pipeline to tag and push images.