variable "gcp_project_id" {
  description = "The GCP Project ID"
  type        = string
  default     = "matthewc"
}

variable "gcp_region" {
  description = "The GCP region to deploy resources in"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "The GCP zone to deploy resources in"
  type        = string
  default     = "us-central1-c"
}