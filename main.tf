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

# [REMOVED] google_compute_address (Static IP) to save costs
# [REMOVED] google_compute_firewall (Cloudflare Tunnel creates an outbound connection)

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

  # Startup script to install and configure Cloudflare Tunnel automatically
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    
    # 1. Add Cloudflare GPG key and repository
    mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list
    
    # 2. Install cloudflared
    apt-get update && apt-get install -y cloudflared

    # 3. Install and start the service with the provided token
    if ! systemctl is-active --quiet cloudflared; then
      cloudflared service install "${var.cloudflare_tunnel_token}" || true
      systemctl start cloudflared
    fi
  EOT
}
