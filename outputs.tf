output "artifact_registry_repository_url" {
  value = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${var.gcp_project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}
