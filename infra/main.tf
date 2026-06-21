terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Activation automatique des APIs GCP requises
variable "gcp_services" {
  type        = list(string)
  description = "Liste des APIs GCP à activer pour le projet"
  default     = [
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "cloudscheduler.googleapis.com",
    "bigquery.googleapis.com",
    "monitoring.googleapis.com"
  ]
}

resource "google_project_service" "gcp_services" {
  for_each           = toset(var.gcp_services)
  service            = each.key
  disable_on_destroy = false
}

# ==========================================
# 1. Google Cloud Storage (Site Statique)
# ==========================================

resource "google_storage_bucket" "static_site" {
  name          = var.bucket_name
  location      = "EU"
  force_destroy = true

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["Content-Type", "Cache-Control", "ETag"]
    max_age_seconds = 3600
  }
}

# Rendre le bucket public en lecture seule
resource "google_storage_bucket_iam_member" "public_viewer" {
  bucket = google_storage_bucket.static_site.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# ==========================================
# 2. BigQuery (Dataset Public & Table)
# ==========================================

resource "google_bigquery_dataset" "spot_capacity" {
  dataset_id  = var.dataset_id
  location    = "EU"
  description = "Dataset public hébergeant l'historique de capacité des VM Spot GCP"

  depends_on = [google_project_service.gcp_services]
}

# Rendre le dataset public pour allUsers (Lecture seule)
resource "google_bigquery_dataset_access" "public_reader" {
  dataset_id = google_bigquery_dataset.spot_capacity.dataset_id
  role       = "roles/bigquery.dataViewer"
  iam_member = "allUsers"
}

# Table partitionnée et clustérisée
resource "google_bigquery_table" "history" {
  dataset_id          = google_bigquery_dataset.spot_capacity.dataset_id
  table_id            = var.table_id
  deletion_protection = false

  time_partitioning {
    type          = "DAY"
    field         = "timestamp"
    expiration_ms = 31536000000 # 1 an en millisecondes
  }

  clustering = ["region", "machine_type", "zone"]

  schema = <<EOF
[
  {
    "name": "timestamp",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Date et heure de la collecte"
  },
  {
    "name": "region",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Région GCP"
  },
  {
    "name": "zone",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Zone GCP (optionnel)"
  },
  {
    "name": "machine_type",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Type de machine de la VM"
  },
  {
    "name": "obtainability_score",
    "type": "FLOAT64",
    "mode": "REQUIRED",
    "description": "Score d'obtention de 0.0 à 1.0"
  },
  {
    "name": "expected_uptime_days",
    "type": "FLOAT64",
    "mode": "NULLABLE",
    "description": "Uptime estimé en jours"
  }
]
EOF
}

# ==========================================
# 3. Artifact Registry (Dépôt Docker)
# ==========================================

resource "google_artifact_registry_repository" "spot_capacity_repo" {
  location      = var.region
  repository_id = var.repo_name
  description   = "Dépôt Docker pour le collecteur de capacité Spot"
  format        = "DOCKER"

  depends_on = [google_project_service.gcp_services]
}

# ==========================================
# 4. Comptes de Service et IAM
# ==========================================

# Compte de service du collecteur
resource "google_service_account" "fetcher" {
  account_id   = var.fetcher_sa_name
  display_name = "SA pour Visualiseur Capacité Spot"
}

# Attributions de rôles niveau projet pour le fetcher
resource "google_project_iam_member" "fetcher_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.fetcher.email}"
}

resource "google_project_iam_member" "fetcher_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.fetcher.email}"
}

resource "google_project_iam_member" "fetcher_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.fetcher.email}"
}

# Droit d'écriture sur le bucket GCS pour le fetcher
resource "google_storage_bucket_iam_member" "fetcher_gcs_admin" {
  bucket = google_storage_bucket.static_site.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.fetcher.email}"
}

# Compte de service pour le Scheduler
resource "google_service_account" "scheduler" {
  account_id   = var.scheduler_sa_name
  display_name = "SA pour déclencheur Cloud Scheduler"
}

# Attribuer les droits d'invocation de Cloud Run au Scheduler
resource "google_project_iam_member" "scheduler_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

# ==========================================
# 5. Cloud Run Job
# ==========================================

resource "google_cloud_run_v2_job" "fetcher" {
  name     = var.job_name
  location = var.region

  depends_on = [
    google_project_service.gcp_services,
    google_project_iam_member.fetcher_compute_viewer,
    google_project_iam_member.fetcher_bq_editor
  ]

  template {
    template {
      service_account = google_service_account.fetcher.email
      containers {
        # Image de démarrage temporaire, le CI/CD (Cloud Build) mettra à jour cette image.
        image = "us-docker.pkg.dev/cloudrun/container/hello:latest"
        
        env {
          name  = "GCP_PROJECT"
          value = var.project_id
        }
        env {
          name  = "BQ_DATASET"
          value = var.dataset_id
        }
        env {
          name  = "BQ_TABLE"
          value = var.table_id
        }
        env {
          name  = "GCS_BUCKET"
          value = var.bucket_name
        }
        env {
          name  = "REGIONS"
          value = var.regions
        }
        env {
          name  = "MACHINE_TYPES"
          value = var.machine_types
        }
      }
    }
  }

  # Évite les conflits de déploiement entre Terraform et Cloud Build (CI/CD)
  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image
    ]
  }
}

# ==========================================
# 6. Cloud Scheduler
# ==========================================

resource "google_cloud_scheduler_job" "hourly_fetch" {
  name             = var.scheduler_job_name
  region           = var.region
  schedule         = "0 * * * *"

  depends_on = [
    google_project_service.gcp_services,
    google_project_iam_member.scheduler_run_invoker,
    google_cloud_run_v2_job.fetcher
  ]
  time_zone        = "Etc/UTC"
  attempt_deadline = "320s"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.fetcher.name}:run"
    
    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

# ==========================================
# 7. Monitoring et Alertes
# ==========================================

# Canal de notification E-mail (facultatif, créé seulement si alert_email est défini)
resource "google_monitoring_notification_channel" "email" {
  count        = var.alert_email != "" ? 1 : 0
  display_name = "Spotwatcher Alerts Email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
  
  depends_on = [google_project_service.gcp_services]
}

# Alerte sur échec d'exécution du Job Cloud Run (Alerte basée sur les Logs)
resource "google_monitoring_alert_policy" "job_failure" {
  display_name = "Spot Capacity Fetcher Job Failure Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "Cloud Run Job log error"
    condition_matched_log {
      filter = "resource.type = \"cloud_run_job\" AND resource.labels.job_name = \"${google_cloud_run_v2_job.fetcher.name}\" AND severity >= ERROR"
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }

  notification_channels = var.alert_email != "" ? [google_monitoring_notification_channel.email[0].name] : []

  depends_on = [google_project_service.gcp_services]
}
