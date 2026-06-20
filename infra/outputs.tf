output "website_url" {
  value       = "http://storage.googleapis.com/${var.bucket_name}/index.html"
  description = "L'URL publique d'accès direct au site statique hébergé sur GCS."
}

output "artifact_registry_repo" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repo_name}"
  description = "L'URL du dépôt Artifact Registry pour y pousser l'image Docker."
}

output "fetcher_service_account_email" {
  value       = "${var.fetcher_sa_name}@${var.project_id}.iam.gserviceaccount.com"
  description = "L'email du compte de service utilisé par le collecteur."
}
