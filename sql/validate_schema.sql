-- Requête de validation du schéma et des données
-- Permet de vérifier les insertions récentes, la distribution géographique des mesures, 
-- et de détecter d'éventuels doublons de collecte.

-- 1. Résumé des dernières collectes (Nombre de lignes par heure sur les dernières 24h)
SELECT
  TIMESTAMP_TRUNC(timestamp, HOUR) AS run_hour,
  COUNT(1) AS total_records,
  COUNT(DISTINCT region) AS active_regions,
  COUNT(DISTINCT machine_type) AS active_machine_types,
  ROUND(AVG(obtainability_score), 2) AS avg_obtainability
FROM
  `{GCP_PROJECT}.{BQ_DATASET}.{BQ_TABLE}`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY
  run_hour
ORDER BY
  run_hour DESC;

-- 2. Détection de doublons (Idempotence) : cherche si pour un même timestamp, 
-- une même région, zone et machine_type, on a plusieurs enregistrements.
SELECT
  timestamp,
  region,
  COALESCE(zone, 'ALL') AS zone,
  machine_type,
  COUNT(1) AS occurrence_count
FROM
  `{GCP_PROJECT}.{BQ_DATASET}.{BQ_TABLE}`
WHERE
  timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)
GROUP BY
  1, 2, 3, 4
HAVING
  occurrence_count > 1
ORDER BY
  occurrence_count DESC
LIMIT 10;
