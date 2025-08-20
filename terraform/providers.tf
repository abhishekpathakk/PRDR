provider "google" {
  project = var.project_id
  region  = var.primary_region
}

provider "google" {
  alias   = "dr"
  project = var.project_id
  region  = var.dr_region
}
