# main.tf

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

# Fetch current project details to get the Project Number
data "google_project" "current" {}

# --- SERVICE ACCOUNTS ---

# 1. The RUN identity (used by the VM)
resource "google_service_account" "vm_service_account" {
  account_id   = "app-server-identity"
  display_name = "Service Account for App Server VM"
}

# 2. The BUILD identity (used by GitHub Actions)
resource "google_service_account" "builder_service_account" {
  account_id   = "github-actions-builder"
  display_name = "GitHub Actions Builder"
}

# --- ARTIFACT REGISTRY SETUP ---

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "docker_repo" {
  depends_on = [google_project_service.artifactregistry]

  location      = var.gcp_region
  repository_id = "app-images"
  description   = "Docker repository for application images"
  format        = "DOCKER"
}

# --- PERMISSIONS: BUILDER (GitHub Actions) ---

# Allow Builder to PUSH images
resource "google_artifact_registry_repository_iam_member" "writer_binding" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.builder_service_account.email}"
}

# Allow GitHub to impersonate the Builder account
resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.builder_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repository}"
}

# --- PERMISSIONS: RUNNER (VM Instance) ---

# Allow VM to PULL images
resource "google_artifact_registry_repository_iam_member" "reader_binding" {
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "log_writer" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "metric_writer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# --- WORKLOAD IDENTITY INFRASTRUCTURE ---

resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "attribute.repository_owner == '${split("/", var.github_repository)[0]}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --- NETWORKING & FIREWALL ---

resource "google_compute_firewall" "allow_wireguard_multiport" {
  name    = "allow-wireguard-multiport"
  network = "default"
  allow {
    protocol = "udp"
    ports    = ["51820", "53", "443", "80", "4500"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_http_https_tcp" {
  name    = "allow-http-https-tcp"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
}

# --- COMPUTE INSTANCE ---

resource "google_compute_instance" "default" {
  name         = "app-server-1"
  machine_type = "e2-micro"
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
    }
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = <<-EOT
      dev:${file("${path.root}/keys/gcp-apps-server.pub")}
      dev:${file("${path.root}/keys/gcp-apps-server-cicd.pub")}
    EOT
  }

  # Startup script: Configures Users, Permissions, AND Cloudflare Tunnel
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    
    # Clean up default OS services to free Port 80
    apt-get purge -y apache2 apache2-utils apache2-bin apache2.2-common || true
    apt-get autoremove -y || true

    # User & Permissions Setup
    if ! id "dev" &>/dev/null; then
        useradd -m -s /bin/bash dev
    fi
    echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev
    chmod 0440 /etc/sudoers.d/dev
    groupadd docker || true
    usermod -aG docker dev
    
    # Cloudflare Tunnel Setup
    mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list
    apt-get update && apt-get install -y cloudflared
    
    if ! systemctl is-active --quiet cloudflared; then
      cloudflared service install "${var.cloudflare_tunnel_token}" || true
      systemctl start cloudflared
    fi
  EOT
}
