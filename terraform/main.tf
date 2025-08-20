resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "prdr-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "pr" {
  name          = "pr-subnet"
  ip_cidr_range = "10.10.0.0/20"
  region        = var.primary_region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

resource "google_compute_subnetwork" "dr" {
  name          = "dr-subnet"
  ip_cidr_range = "10.40.0.0/20"
  region        = var.dr_region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.50.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.60.0.0/20"
  }
}

resource "google_container_cluster" "pr" {
  name     = var.pr_cluster_name
  location = var.primary_zone
  deletion_protection = false

  remove_default_node_pool = false
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.pr.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.pr.secondary_ip_range[1].range_name
  }
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.pr.id

  node_config {
    machine_type = var.node_machine_type
    disk_type    = var.node_disk_type
    disk_size_gb = var.node_disk_size_gb
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      site = "pr"
    }
  }

  depends_on = [google_project_service.container, google_project_service.compute]

  provisioner "local-exec" {
    command = "bash -c 'mkdir -p ${path.module}/kubeconfigs && gcloud container clusters get-credentials ${self.name} --zone ${var.primary_zone} --project ${var.project_id} && kubectl config use-context gke_${var.project_id}_${var.primary_zone}_${self.name} && kubectl config view --raw --minify --flatten > ${path.module}/kubeconfigs/pr.yaml'"
  }
}

resource "google_container_cluster" "dr" {
  provider = google.dr

  name     = var.dr_cluster_name
  location = var.dr_zone
  deletion_protection = false

  remove_default_node_pool = false
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.dr.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.dr.secondary_ip_range[1].range_name
  }
  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.dr.id

  node_config {
    machine_type = var.node_machine_type
    disk_type    = var.node_disk_type
    disk_size_gb = var.node_disk_size_gb
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    labels = {
      site = "dr"
    }
  }

  depends_on = [google_project_service.container, google_project_service.compute]

  provisioner "local-exec" {
    command = "bash -c 'mkdir -p ${path.module}/kubeconfigs && gcloud container clusters get-credentials ${self.name} --zone ${var.dr_zone} --project ${var.project_id} && kubectl config use-context gke_${var.project_id}_${var.dr_zone}_${self.name} && kubectl config view --raw --minify --flatten > ${path.module}/kubeconfigs/dr.yaml'"
  }
}
