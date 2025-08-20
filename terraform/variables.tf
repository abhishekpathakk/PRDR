variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "primary_region" {
  description = "Primary region for PR cluster"
  type        = string
  default     = "us-central1"
}

variable "dr_region" {
  description = "DR region for DR cluster"
  type        = string
  default     = "us-east1"
}

variable "primary_zone" {
  description = "Primary zone (zonal cluster)"
  type        = string
  default     = "us-central1-a"
}

variable "dr_zone" {
  description = "DR zone (zonal cluster)"
  type        = string
  default     = "us-east1-b"
}

variable "pr_cluster_name" {
  description = "Name of primary cluster"
  type        = string
  default     = "pr-cluster"
}

variable "dr_cluster_name" {
  description = "Name of DR cluster"
  type        = string
  default     = "dr-cluster"
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "node_disk_type" {
  description = "Boot disk type for node pool (use pd-standard to avoid SSD quota)"
  type        = string
  default     = "pd-standard"
}

variable "node_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}
