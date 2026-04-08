# GCP Server Infrastructure (Terraform)

This repository contains the Terraform configuration for provisioning the foundational infrastructure on Google Cloud Platform.

**Update:** This infrastructure now uses **Cloudflare Tunnel** for connectivity. The server does not have a static public IP and does not allow inbound connections from the internet. All traffic (SSH and HTTP) is routed securely through Cloudflare.

## Architecture Overview

- **Server Provisioning**: Deploys a GCE VM instance (e2-micro) with an ephemeral IP (cost-optimized).
- **Cloudflare Tunnel**: Automatically installed on the VM to secure ingress traffic.
- **Artifact Registry**: Creates a private Docker repository.
- **Workload Identity**: Configured to allow CI/CD pipelines to securely push infrastructure images.

## Migration & Initial Setup

### Step 1: Create Cloudflare Tunnel (Manual Step)

Because this is a one-time setup involving a third-party secret, we generate the tunnel in the Cloudflare Dashboard:

1.  Log in to Cloudflare Zero Trust > **Networks** > **Tunnels**.
2.  Click **Create a Tunnel**. Select **Cloudflared**.
3.  Name it `gcp-server` and save.
4.  **Copy the Tunnel Token** (It looks like a long base64 string). You do _not_ need to run the installation commands shown on the screen; Terraform will do that.
5.  In the **Public Hostnames** tab of the tunnel config:
    - **SSH Access**: `ssh.yourdomain.com` -> `ssh://localhost:22`
    - **Forward Proxy**: `proxy.yourdomain.com` -> `https://localhost:443`
    - **Wildcard Apps**: `*.apps.yourdomain.com` -> `http://localhost:80`

### Step 2: Configure Terraform Secrets

1.  **Prepare SSH Keys**: Place your public keys in the `keys/` directory of this repo:
    - `keys/gcp-apps-server.pub` (for manual local access)
    - `keys/gcp-apps-server-cicd.pub` (for CI/CD pipeline access)
2.  Create a file named `terraform.tfvars` in this directory (do not commit this file):
    ```hcl
    cloudflare_tunnel_token = "eyJhIjoi..."
    wif_pool_id             = "github-pool"
    github_repository       = "your-username/gcp-server-config"
    ```

### Step 3: Provision Infrastructure

1.  **Initialize**: `terraform init`
2.  **Apply**: `terraform apply`

### Step 4: Build Shared Infrastructure Image

This infrastructure uses a custom Caddy build with the `forwardproxy` plugin. Because the micro instance has limited RAM, the image is built in CI/CD.

1.  Add `GCP_PROJECT_ID`, `GCP_SERVICE_ACCOUNT`, and `GCP_WORKLOAD_IDENTITY_PROVIDER` secrets to this repository in GitHub.
2.  Go to the **Actions** tab in this repo and run the **"Build and Push Custom Caddy"** workflow.
3.  Verify the image `caddy-custom:latest` exists in your GCP Artifact Registry.

### Step 5: Configure Local SSH Access

Connect via the Cloudflare Tunnel ProxyCommand:

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

### Step 6: Integration Details

To deploy applications to this infrastructure, you will need the following values (available after terraform apply):

1.  **`SERVER_HOSTNAME`**: `ssh.yourdomain.com`
2.  **`PROXY_URL`**: `https://user:password@proxy.yourdomain.com:443`
3.  **`GCP_PROJECT_ID`: Your Google Cloud Project ID value.
