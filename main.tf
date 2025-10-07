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

resource "google_compute_address" "static_ip" {
  name = "vm-static-ip"
}

resource "google_compute_instance" "default" {
  name         = "app-server-1"
  machine_type = "e2-micro"
  
  # --- THIS LINE IS THE FIX ---
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
      nat_ip = google_compute_address.static_ip.address
    }
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "dev:${file("~/.ssh/id_ed25519_gcp.pub")}"
  }

  tags = ["http-server", "https-server"]
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "allow-http-https"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  target_tags   = ["http-server", "https-server"]
  source_ranges = ["0.0.0.0/0"]
}