# Spécifications : Déploiement & Infrastructure

Afin de provisionner cette architecture "Google Native", nous recommandons d'utiliser `gcloud` ou Terraform. Voici les étapes de déploiement à automatiser.

## 1. Google Cloud Storage (Site Web Statique)
```bash
# Créer le bucket
gcloud storage buckets create gs://capacity.mon-domaine.com --location=EU

# Configurer l'hébergement web statique
gcloud storage buckets update gs://capacity.mon-domaine.com --web-main-page-suffix=index.html --web-error-page=404.html

# Rendre le bucket public (Lecture seule)
gcloud storage buckets add-iam-policy-binding gs://capacity.mon-domaine.com \
    --member=allUsers --role=roles/storage.objectViewer
```

## 2. BigQuery (Public Dataset)
```bash
# Créer le dataset
bq mk --dataset --location=EU my_project:spot_capacity

# Rendre le dataset public (allUsers)
bq update --source <(bq show --format=json my_project:spot_capacity | jq '.access += [{"role":"READER","specialGroup":"allAuthenticatedUsers"}]') my_project:spot_capacity

# Créer la table avec Partitionnement et Clustering
bq mk --table \
  --time_partitioning_field timestamp \
  --time_partitioning_type DAY \
  --clustering_fields region,machine_type,zone \
  my_project:spot_capacity.history \
  timestamp:TIMESTAMP,region:STRING,zone:STRING,machine_type:STRING,obtainability_score:FLOAT64,expected_uptime_days:FLOAT64
```

## 3. Cloud Run & Cloud Scheduler (Job de Collecte)
Le script de collecte (Python) nécessitera un compte de service ayant les rôles :
- `roles/compute.viewer` (Pour lire `advice.capacity`)
- `roles/bigquery.dataEditor` (Pour écrire dans la table)
- `roles/storage.objectAdmin` (Pour uploader le `data.json` écrasant l'ancien)

```bash
# Déployer le script en tant que Cloud Run Job
gcloud run jobs create spot-capacity-fetcher \
    --image gcr.io/my_project/capacity-fetcher \
    --service-account my-fetcher-sa@my_project.iam.gserviceaccount.com \
    --region europe-west1

# Configurer le Cloud Scheduler pour déclencher le job toutes les heures
gcloud scheduler jobs create http hourly-capacity-fetch \
    --schedule="0 * * * *" \
    --uri="https://europe-west1-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/my_project/jobs/spot-capacity-fetcher:run" \
    --http-method=POST \
    --oauth-service-account-email=my-scheduler-sa@my_project.iam.gserviceaccount.com \
    --location=europe-west1
```

## Conclusion
Avec cette architecture :
1. Les coûts sont quasiment nuls (Cloud Run dans le Free Tier, GCS très peu coûteux, BigQuery facturé uniquement au stockage de quelques Mo).
2. Le site est 100% statique et très rapide, sans maintenance de serveur.
3. Les données historiques sont stockées proprement pour des analyses plus poussées via SQL par la communauté publique.
