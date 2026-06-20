from google.cloud import bigquery
from google.cloud import storage
import json
import logging
import os
from datetime import datetime, timezone

class GCSExporter:
    def __init__(self, project_id: str, dataset_id: str, table_id: str, bucket_name: str):
        self.project_id = project_id
        self.dataset_id = dataset_id
        self.table_id = table_id
        self.bucket_name = bucket_name
        self.bq_client = bigquery.Client(project=self.project_id)
        self.storage_client = storage.Client(project=self.project_id)

    def run_export(self) -> bool:
        """
        Exécute la requête SQL d'agrégation, formate en JSON structuré
        et l'éploie dans le bucket GCS de destination.
        """
        # 1. Charger la requête SQL
        sql_path = os.path.join(os.path.dirname(__file__), "..", "sql", "aggregate_history.sql")
        if not os.path.exists(sql_path):
            logging.error(f"Fichier SQL introuvable : {sql_path}")
            return False

        with open(sql_path, "r", encoding="utf-8") as f:
            query_template = f.read()

        # Remplacer les variables du template
        query = query_template.format(
            GCP_PROJECT=self.project_id,
            BQ_DATASET=self.dataset_id,
            BQ_TABLE=self.table_id
        )

        # 2. Exécuter la requête
        logging.info("Exécution de la requête SQL d'agrégation BigQuery...")
        try:
            query_job = self.bq_client.query(query)
            rows = list(query_job.result())
        except Exception as e:
            logging.error(f"Erreur lors de l'exécution SQL BigQuery : {e}")
            return False

        # 3. Formater les lignes plates dans la structure hiérarchique JSON
        # {
        #   "last_updated": "...",
        #   "series": [
        #      {
        #        "region": "...",
        #        "zone": "...",
        #        "machine_type": "...",
        #        "data": [{"timestamp": "...", "score": 0.8, "uptime": 3.2}, ...]
        #      }
        #   ]
        # }
        series_map = {}
        for row in rows:
            # Créer une clé unique pour chaque série temporelle
            key = (row.region, row.zone, row.machine_type)
            
            # Convertir le timestamp BigQuery en chaîne ISO formatée
            # (Le résultat de TIMESTAMP_TRUNC en BQ renvoie un objet datetime)
            ts_str = row.timestamp.replace(tzinfo=timezone.utc).isoformat()
            
            data_point = {
                "timestamp": ts_str,
                "score": float(row.obtainability_score),
                "uptime": float(row.expected_uptime_days)
            }
            
            if key not in series_map:
                series_map[key] = {
                    "region": row.region,
                    "zone": row.zone,
                    "machine_type": row.machine_type,
                    "data": []
                }
            
            series_map[key]["data"].append(data_point)

        # Créer le payload final
        payload = {
            "last_updated": datetime.now(timezone.utc).isoformat(),
            "project_id": self.project_id,
            "dataset_id": self.dataset_id,
            "series": list(series_map.values())
        }

        # 4. Uploader sur Cloud Storage
        json_content = json.dumps(payload, ensure_ascii=False, indent=2)
        try:
            bucket = self.storage_client.bucket(self.bucket_name)
            blob = bucket.blob("data.json")
            
            logging.info(f"Upload du fichier data.json vers gs://{self.bucket_name}/data.json...")
            # Définir le cache de 5 minutes (300 secondes) pour éviter les re-téléchargements inutiles
            blob.cache_control = "public, max-age=300"
            blob.content_type = "application/json"
            blob.upload_from_string(json_content, content_type="application/json")
            
            logging.info("Upload GCS réussi !")
            return True
        except Exception as e:
            logging.error(f"Erreur lors du dépôt GCS : {e}")
            return False
