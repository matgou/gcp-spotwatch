import os
import sys
import logging

# Configurer le logging de base
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)

# Chargement et validation des variables d'environnement
GCP_PROJECT = os.environ.get("GCP_PROJECT")
if not GCP_PROJECT:
    logging.error("La variable d'environnement GCP_PROJECT est manquante.")
    sys.exit(1)

BQ_DATASET = os.environ.get("BQ_DATASET", "spot_capacity")
BQ_TABLE = os.environ.get("BQ_TABLE", "history")
GCS_BUCKET = os.environ.get("GCS_BUCKET", "spot-capacity-static-site")

# Parsing des listes de régions et types de machines
REGIONS_RAW = os.environ.get("REGIONS", "europe-west1,europe-west3,us-central1,us-east1")
REGIONS = [r.strip() for r in REGIONS_RAW.split(",") if r.strip()]

MACHINE_TYPES_RAW = os.environ.get("MACHINE_TYPES", "n2-standard-2,n2-standard-4,t2d-standard-4,t2d-standard-8")
MACHINE_TYPES = [m.strip() for m in MACHINE_TYPES_RAW.split(",") if m.strip()]

logging.info(f"Configuration chargée:")
logging.info(f"- Projet GCP    : {GCP_PROJECT}")
logging.info(f"- BigQuery      : {BQ_DATASET}.{BQ_TABLE}")
logging.info(f"- Bucket GCS    : {GCS_BUCKET}")
logging.info(f"- Régions à suivre : {REGIONS}")
logging.info(f"- Types de machine : {MACHINE_TYPES}")
