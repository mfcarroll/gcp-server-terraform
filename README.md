# GCP Server Infrastructure (Terraform)

This repository contains the Terraform configuration for provisioning the foundational infrastructure on Google Cloud Platform.

**Update:** This infrastructure now uses **Cloudflare Tunnel** for connectivity. The server does not have a static public IP and does not allow inbound connections from the internet. All traffic (SSH and HTTP) is routed securely through Cloudflare.

## Architecture Overview

- **Server Provisioning**: Deploys a GCE VM instance (e2-micro) with an ephemeral IP (cost-optimized).
- **Cloudflare Tunnel**: Automatically installed on the VM to secure ingress traffic.
- **Artifact Registry**: Creates a private Docker repository.

## Migration & Initial Setup

### Step 1: Create Cloudflare Tunnel (Manual Step)

Because this is a one-time setup involving a third-party secret, we generate the tunnel in the Cloudflare Dashboard:

1.  Log in to Cloudflare Zero Trust > **Networks** > **Tunnels**.
2.  Click **Create a Tunnel**. Select **Cloudflared**.
3.  Name it `gcp-server` and save.
4.  **Copy the Tunnel Token** (It looks like a long base64 string). You do _not_ need to run the installation commands shown on the screen; Terraform will do that.
5.  In the **Public Hostnames** tab of the tunnel config:
    - Add a hostname for SSH: e.g., `ssh.yourdomain.com` -> Service: `ssh://localhost:22`
    - Add a wildcard for apps: `*.apps.yourdomain.com` -> Service: `http://localhost:80`

### Step 2: Configure Terraform Secrets

1.  Create a file named `terraform.tfvars` in this directory (do not commit this file).
2.  Add your tunnel token:
    ```hcl
    cloudflare_tunnel_token = "eyJhIjoi..."
    ```

### Step 3: Provision Infrastructure

1.  **Initialize**: `terraform init`
2.  **Apply**: `terraform apply`
    - _Note:_ If you are migrating from the old static IP setup, Terraform will destroy the Static IP and Firewall resources. This will immediately drop any existing SSH connections.

### Step 4: Configure Local SSH Access

Since the server has no public IP, you must connect via the Cloudflare Tunnel.

1.  Install `cloudflared` on your local machine.
2.  Update your `~/.ssh/config`:
    ```
    Host gcp-server
      HostName ssh.yourdomain.com
      User dev
      IdentityFile ~/.ssh/id_ed25519_gcp
      ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
    ```
3.  Connect: `ssh gcp-server`

### Step 5: Update CI/CD Secrets

Go to your `gcp-service-template` repository (and any others) settings:

1.  Update `SERVER_IP` secret to your new SSH hostname: `ssh.yourdomain.com`.
2.  Ensure your GitHub Action runners (in `gcp-server-config`) have `cloudflared` installed to utilize the ProxyCommand.
