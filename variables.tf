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

variable "cloudflare_tunnel_token" {
  description = "The token for the Cloudflare Tunnel"
  type        = string
  sensitive   = true
}

variable "wif_pool_id" {
  description = "The ID of the Workload Identity Pool (e.g., github-pool)"
  type        = string
  default     = "github-pool"
}

variable "github_repository" {
  description = "The GitHub repository allowed to impersonate the service account (e.g., owner/repo)"
  type        = string
  default     = "mfcarroll/gcp-server-config"
}
