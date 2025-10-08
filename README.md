# GCP Server Infrastructure (Terraform)

This repository contains the Terraform configuration for provisioning the foundational infrastructure on Google Cloud Platform. This setup is the bedrock of the entire application hosting environment and is typically only run once.

## Architecture Overview
This Terraform configuration creates the core, non-application-specific resources required to run the containerized application platform. It is the first step in setting up the environment.

* **Server Provisioning**: Deploys a GCE VM instance, a static IP, and necessary firewall rules.
* **Artifact Registry**: Creates a private Docker repository to securely store application images.
* **Service Accounts**: Configures the necessary IAM service accounts and permissions for the VM to access the Artifact Registry.

Once this infrastructure is provisioned, server state is managed by the Ansible configuration in the `mfcarroll/gcp-server-config` repository, and application deployments are handled via the `mfcarroll/gcp-service-template`.

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