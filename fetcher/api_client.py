import time
import re
import requests
import google.auth
import google.auth.transport.requests
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
import logging

# Scopes requis pour requêter les API Compute Engine
SCOPES = ['https://www.googleapis.com/auth/compute', 'https://www.googleapis.com/auth/cloud-platform']

def parse_duration_to_days(duration_str: str) -> float:
    """
    Convertit une chaîne de durée Google API (ex: "86400s", "25200s") en nombre de jours.
    """
    if not duration_str:
        return 0.0
    match = re.match(r'^([0-9\.]+)\s*s$', duration_str.strip())
    if match:
        seconds = float(match.group(1))
        return round(seconds / 86400.0, 2)
    return 0.0

class GCPCapacityClient:
    def __init__(self, project_id: str):
        self.project_id = project_id
        self.credentials, _ = google.auth.default(scopes=SCOPES)
        self.auth_req = google.auth.transport.requests.Request()

    def _get_headers(self) -> dict:
        """
        Génère les en-têtes d'authentification OAuth2.
        """
        if not self.credentials.valid:
            logging.info("Rafraîchissement des credentials Google OAuth2...")
            self.credentials.refresh(self.auth_req)
        return {
            'Authorization': f'Bearer {self.credentials.token}',
            'Content-Type': 'application/json'
        }

    # Retry avec exponential backoff pour gérer les erreurs temporaires 429 ou 503
    @retry(
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(requests.exceptions.RequestException),
        reraise=True
    )
    def fetch_spot_capacity(self, region: str, machine_type: str) -> dict:
        """
        Appelle l'API Compute advice.capacity pour obtenir le score d'une machine dans une région.
        """
        url = f"https://compute.googleapis.com/compute/beta/projects/{self.project_id}/regions/{region}/advice/capacity"
        
        # Payload pour demander l'analyse d'un seul type de machine
        payload = {
            "instanceProperties": {
                "scheduling": {
                    "provisioningModel": "SPOT"
                }
            },
            "instanceFlexibilityPolicy": {
                "instanceSelections": {
                    "selection_main": {
                        "machineTypes": [machine_type]
                    }
                }
            },
            "size": 1,
            "distributionPolicy": {
                "targetShape": "BALANCED"
            }
        }

        logging.info(f"Appel API advice.capacity pour {machine_type} dans {region}...")
        response = requests.post(url, headers=self._get_headers(), json=payload, timeout=15)
        
        # Gérer spécifiquement le rate limit ou les indisponibilités temporaires
        if response.status_code in [429, 503]:
            logging.warning(f"API retournée avec le statut {response.status_code}. Tentative de retry...")
            response.raise_for_status()
        
        response.raise_for_status()
        data = response.json()

        # Parsing de la réponse GCP
        # Structure de réponse attendue :
        # {
        #   "recommendations": [
        #     {
        #       "scores": { "obtainability": 0.9, "estimatedUptime": "86400s" },
        #       "shards": [...]
        #     }
        #   ]
        # }
        recommendations = data.get("recommendations", [])
        if not recommendations:
            return {
                "obtainability_score": 0.0,
                "expected_uptime_days": 0.0,
                "zones": []
            }

        rec = recommendations[0]
        scores = rec.get("scores", {})
        obtainability = float(scores.get("obtainability", 0.0))
        
        uptime_str = scores.get("estimatedUptime", "")
        uptime_days = parse_duration_to_days(uptime_str)

        # Extraction des zones recommandées par les shards
        zones = []
        for shard in rec.get("shards", []):
            zone_url = shard.get("zone", "")
            if zone_url:
                # Extraire le nom de la zone de l'URL (ex: ".../zones/europe-west1-b")
                zone_name = zone_url.split("/")[-1]
                zones.append(zone_name)

        return {
            "obtainability_score": obtainability,
            "expected_uptime_days": uptime_days,
            "zones": list(set(zones))
        }
