terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name = "rgrvpc"
}

resource "google_compute_instance" "vm_instance" {
  name         = var.machine_name
  machine_type = "e2-medium" # Don't need much for small server
  tags         = ["jenkins"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-minimal-2210-kinetic-amd64-v20230425"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

resource "google_compute_firewall" "rules" {
  project       = var.project
  name          = "allowall"
  network       = google_compute_network.vpc_network.self_link
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["20", "22", "80", "8080", "1000-2000"]
  }

  source_tags = ["vpc"]
  target_tags = ["jenkins"]
}
