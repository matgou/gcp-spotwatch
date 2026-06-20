# Spécifications : Pipeline de Données & BigQuery

## 1. Source de Données : API Compute Engine
L'API REST à interroger est la méthode beta `advice.capacity`.
- **URL** : `POST https://compute.googleapis.com/compute/beta/projects/{project}/locations/{region}/advice/capacity`
- **Body** : Doit contenir les types de machines cibles (ex: `n2-standard-4`, `t2d-standard-8`) et la politique de distribution (`ANY`).

Cette API renvoie un "score d'obtention" (`obtainability`) compris entre 0.0 et 1.0, indiquant la disponibilité des VM Spot demandées.

## 2. Job de Collecte (Cloud Run)
Un script écrit en Python (ou Go) sera packagé dans un conteneur Cloud Run Job ou déployé via Cloud Functions.
- **Déclencheur** : Cloud Scheduler configuré avec un cron `0 * * * *` (toutes les heures).
- **Logique** :
  1. Authentification avec les credentials par défaut (Application Default Credentials).
  2. Appel de l'API `advice.capacity` pour une liste prédéfinie de régions (ex: `europe-west1`, `us-central1`) et de types de machines.
  3. Formatage de la réponse.
  4. Insertion des données dans BigQuery (via le client BigQuery).
  5. **Génération Statistique** : Exécution d'une requête SQL sur BigQuery pour extraire les 7 ou 30 derniers jours de données formatées.
  6. Export de ces résultats sous forme de fichier `capacity_data.json` vers le bucket GCS contenant le site statique.

## 3. Schéma BigQuery
Le dataset BigQuery sera rendu accessible publiquement via la gestion des accès (IAM `roles/bigquery.dataViewer` pour `allUsers`), répondant à l'objectif de "public data set".

**Table : `spot_capacity_history`**

| Nom de Colonne | Type de Données | Description |
| :--- | :--- | :--- |
| `timestamp` | `TIMESTAMP` | Date et heure de la mesure |
| `region` | `STRING` | Région GCP (ex: `europe-west1`) |
| `zone` | `STRING` | Zone GCP (optionnel, ex: `europe-west1-b`). Null si la requête couvre toute la région. |
| `machine_type` | `STRING` | Type de machine (ex: `n2-standard-2`) |
| `obtainability_score` | `FLOAT64` | Score de probabilité (0.0 à 1.0) |
| `expected_uptime_days` | `FLOAT64` | Temps de disponibilité attendu (si fourni par l'API) |

**Optimisations BigQuery appliquées (Best Practices) :**
- **Partitionnement (Partitioning)** : Sur la colonne `timestamp` (par jour). **Indispensable** pour une table de séries temporelles (qui plus est publique), afin de limiter le volume de données scannées et le coût des requêtes qui filtrent par date.
- **Clustering** : Sur les colonnes `region`, `machine_type` et `zone`. Les requêtes analytiques cibleront quasi-systématiquement un type de machine ou une région spécifique. Le clustering accélérera l'exécution et réduira davantage les coûts de scan.

## 4. Fichier d'Export JSON (`capacity_data.json`)
Pour que le site statique soit ultra-rapide et n'ait pas besoin d'un backend, le JSON généré par le job de collecte aura la structure suivante :
```json
{
  "last_updated": "2026-06-20T12:00:00Z",
  "series": [
    {
      "region": "europe-west1",
      "machine_type": "n2-standard-4",
      "data": [
        {"timestamp": "2026-06-19T12:00:00Z", "score": 0.8},
        {"timestamp": "2026-06-19T13:00:00Z", "score": 0.9}
      ]
    }
  ]
}
```
