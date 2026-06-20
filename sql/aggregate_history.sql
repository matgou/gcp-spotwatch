-- Requête d'agrégation historique pour le visualiseur statique
-- Cette requête regroupe les données par heure pour éviter les doublons et lisser les mesures
-- Elle récupère les 30 derniers jours de données.

SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS timestamp,
  region,
  COALESCE(zone, 'ALL') AS zone,
  machine_type,
  ROUND(AVG(obtainability_score), 2) AS obtainability_score,
  ROUND(AVG(expected_uptime_days), 1) AS expected_uptime_days
FROM
  `{GCP_PROJECT}.{BQ_DATASET}.{BQ_TABLE}`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY
  timestamp,
  region,
  zone,
  machine_type
ORDER BY
  region,
  machine_type,
  zone,
  timestamp ASC;
