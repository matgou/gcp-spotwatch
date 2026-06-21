variable "project_id" {
  type        = string
  description = "L'identifiant du projet Google Cloud (GCP)."
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "La région par défaut pour le déploiement des ressources."
}

variable "bucket_name" {
  type        = string
  description = "Le nom unique du bucket GCS hébergeant le site statique."
}

variable "dataset_id" {
  type        = string
  default     = "spot_capacity"
  description = "L'identifiant du dataset BigQuery."
}

variable "table_id" {
  type        = string
  default     = "history"
  description = "L'identifiant de la table BigQuery."
}

variable "repo_name" {
  type        = string
  default     = "spot-capacity-repo"
  description = "Le nom du dépôt Artifact Registry pour héberger l'image du conteneur."
}

variable "job_name" {
  type        = string
  default     = "spot-capacity-fetcher"
  description = "Le nom du Cloud Run Job."
}

variable "scheduler_job_name" {
  type        = string
  default     = "hourly-spot-capacity-fetch"
  description = "Le nom de la planification Cloud Scheduler."
}

variable "fetcher_sa_name" {
  type        = string
  default     = "spot-capacity-fetcher-sa"
  description = "Le nom du compte de service pour le collecteur."
}

variable "scheduler_sa_name" {
  type        = string
  default     = "spot-capacity-scheduler-sa"
  description = "Le nom du compte de service pour le Cloud Scheduler."
}

variable "regions" {
  type        = string
  default     = "europe-west1,europe-west3,us-central1,us-east1"
  description = "Liste des régions à suivre, séparées par des virgules."
}

variable "machine_types" {
  type        = string
  default     = "e2-micro,e2-small,e2-medium,e2-standard-2,e2-standard-4,n2-standard-2,n2-standard-4,t2d-standard-1,t2d-standard-2,t2d-standard-4,c2-standard-4"
  description = "Liste des types de machines à suivre, séparées par des virgules."
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "L'adresse email pour recevoir les alertes en cas de panne du collecteur (optionnel)."
}

