from google.cloud import bigquery
import logging
from datetime import datetime, timezone

class BigQueryWriter:
    def __init__(self, project_id: str, dataset_id: str, table_id: str):
        self.project_id = project_id
        self.dataset_id = dataset_id
        self.table_id = table_id
        self.client = bigquery.Client(project=self.project_id)
        self.table_ref = f"{self.project_id}.{self.dataset_id}.{self.table_id}"

    def write_rows(self, results: list) -> bool:
        """
        Insère une liste de mesures dans la table BigQuery.
        results: list de dicts contenant: region, zone, machine_type, score, uptime
        """
        if not results:
            logging.info("Aucun enregistrement à insérer dans BigQuery.")
            return True

        rows_to_insert = []
        current_time = datetime.now(timezone.utc).isoformat()

        for res in results:
            # On insère une ligne par zone recommandée si l'API a retourné des zones,
            # sinon on insère une ligne globale régionale (zone = None)
            zones = res.get("zones", [])
            if not zones:
                rows_to_insert.append({
                    "timestamp": current_time,
                    "region": res["region"],
                    "zone": None,
                    "machine_type": res["machine_type"],
                    "obtainability_score": res["obtainability_score"],
                    "expected_uptime_days": res["expected_uptime_days"]
                })
            else:
                for zone in zones:
                    rows_to_insert.append({
                        "timestamp": current_time,
                        "region": res["region"],
                        "zone": zone,
                        "machine_type": res["machine_type"],
                        "obtainability_score": res["obtainability_score"],
                        "expected_uptime_days": res["expected_uptime_days"]
                    })

        logging.info(f"Insertion de {len(rows_to_insert)} lignes dans BigQuery ({self.table_ref})...")
        try:
            errors = self.client.insert_rows_json(self.table_ref, rows_to_insert)
            if errors == []:
                logging.info("Insertion BigQuery réussie sans erreurs.")
                return True
            else:
                logging.error(f"Erreur lors de l'insertion dans BigQuery : {errors}")
                return False
        except Exception as e:
            logging.error(f"Exception levée lors de l'écriture BigQuery : {e}")
            return False
