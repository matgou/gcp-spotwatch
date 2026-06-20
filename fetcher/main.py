import time
import logging
from config import GCP_PROJECT, BQ_DATASET, BQ_TABLE, GCS_BUCKET, REGIONS, MACHINE_TYPES
from api_client import GCPCapacityClient
from bigquery_writer import BigQueryWriter
from gcs_exporter import GCSExporter

def main():
    logging.info("=== Lancement du collecteur de capacité GCP ===")
    
    # 1. Initialisation des clients
    api_client = GCPCapacityClient(project_id=GCP_PROJECT)
    bq_writer = BigQueryWriter(project_id=GCP_PROJECT, dataset_id=BQ_DATASET, table_id=BQ_TABLE)
    gcs_exporter = GCSExporter(project_id=GCP_PROJECT, dataset_id=BQ_DATASET, table_id=BQ_TABLE, bucket_name=GCS_BUCKET)

    results = []
    
    # 2. Collecte des données en parallèle (max 10 requêtes simultanées)
    # Cela permet de gérer un grand nombre de types de machines (ex: toutes les machines courantes)
    # sans que le script ne mette 10 minutes à s'exécuter, tout en restant sous la limite GCP de 20 QPS.
    from concurrent.futures import ThreadPoolExecutor, as_completed
    
    tasks = []
    for region in REGIONS:
        for machine_type in MACHINE_TYPES:
            tasks.append((region, machine_type))
            
    logging.info(f"Début de la collecte en parallèle pour {len(tasks)} combinaisons...")
    
    def worker(region, machine_type):
        try:
            data = api_client.fetch_spot_capacity(region=region, machine_type=machine_type)
            return {
                "region": region,
                "machine_type": machine_type,
                "obtainability_score": data["obtainability_score"],
                "expected_uptime_days": data["expected_uptime_days"],
                "zones": data["zones"]
            }
        except Exception as e:
            logging.error(f"Échec de récupération pour {machine_type} dans {region} : {e}")
            return None

    # On limite à 10 threads pour rester dans la limite de 20 QPS de GCP
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(worker, r, m): (r, m) for r, m in tasks}
        for future in as_completed(futures):
            res = future.result()
            if res:
                results.append(res)
            # Un léger délai entre les fins de tâches n'est pas nécessaire car l'API est asynchrone et lissée par les workers
            time.sleep(0.05)

    # 3. Écriture dans BigQuery
    bq_success = bq_writer.write_rows(results)
    if not bq_success:
        logging.error("L'écriture dans BigQuery a échoué. Le processus continue pour tenter l'export GCS.")

    # 4. Génération et export du fichier data.json statique vers GCS
    gcs_success = gcs_exporter.run_export()
    if not gcs_success:
        logging.error("L'exportation vers Google Cloud Storage a échoué.")
        
    logging.info("=== Fin de l'exécution du collecteur ===")

if __name__ == "__main__":
    main()
