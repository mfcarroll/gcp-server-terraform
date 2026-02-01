terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

resource "google_service_account" "vm_service_account" {
  account_id   = "app-server-identity"
  display_name = "Service Account for App Server VM"
}

# Enable the Artifact Registry API
resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Create the Docker repository in Artifact Registry
resource "google_artifact_registry_repository" "docker_repo" {
  depends_on = [google_project_service.artifactregistry]

  location      = var.gcp_region
  repository_id = "app-images"
  description   = "Docker repository for application images"
  format        = "DOCKER"
}

# Grant the new service account permission to pull images
resource "google_artifact_registry_repository_iam_member" "reader_binding" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Allow the Service Account to write Logs (for Ops Agent)
resource "google_project_iam_member" "log_writer" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Allow the Service Account to write Metrics (for Ops Agent)
resource "google_project_iam_member" "metric_writer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Allow WireGuard UDP traffic on Port 53
# Required because Cloudflare Tunnel does not proxy UDP, so we need a direct "side door".
resource "google_compute_firewall" "allow_wireguard_multiport" {
  name    = "allow-wireguard-multiport"
  network = "default"

  allow {
    protocol = "udp"
    # 51820 (Standard), 53 (DNS), 443 (HTTPS/QUIC), 80 (HTTP)
    ports    = ["51820", "53", "443", "80"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "default" {
  name         = "app-server-1"
  machine_type = "e2-micro"

  # Allows Terraform to stop and restart the VM for updates that require it.
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Leaving this empty assigns an Ephemeral IP.
      # On e2-micro in free tier regions, this is typically free.
    }
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = <<-EOT
      dev:${file("~/.ssh/id_ed25519_gcp.pub")}
      dev:${file("~/.ssh/id_ed25519_cicd.pub")}
    EOT
  }

  # Startup script: Configures Users, Permissions, AND Cloudflare Tunnel
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e

    # --- 1. User & Permissions Setup ---
    # Ensure the dev user exists
    if ! id "dev" &>/dev/null; then
        useradd -m -s /bin/bash dev
    fi

    # Grant passwordless sudo to dev (Critical for Ansible)
    echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
    chmod 0440 /etc/sudoers.d/dev

    # Add dev to the docker group
    groupadd docker || true
    usermod -aG docker dev

    # --- 2. Cloudflare Tunnel Setup ---
    # Add Cloudflare GPG key and repository
    mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list
    
    # Install cloudflared
    apt-get update && apt-get install -y cloudflared

    # Install and start the service with the provided token
    if ! systemctl is-active --quiet cloudflared; then
      cloudflared service install "${var.cloudflare_tunnel_token}" || true
      systemctl start cloudflared
    fi
  EOT
}
