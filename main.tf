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

resource "google_compute_address" "static_ip" {
  name = "vm-static-ip"
}

resource "google_compute_instance" "default" {
  name         = "app-server-1"
  machine_type = "e2-micro"
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
  target_tags = ["http-server", "https-server"]
  source_ranges = ["0.0.0.0/0"]
}