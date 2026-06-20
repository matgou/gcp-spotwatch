#!/bin/bash
set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Charger le fichier .env
if [ -f "${DIR}/../.env" ]; then
  export $(grep -v '^#' "${DIR}/../.env" | xargs)
fi

if [ -z "${GCS_BUCKET}" ] || [ -z "${GCP_PROJECT}" ]; then
  echo "Erreur: Les variables GCS_BUCKET et GCP_PROJECT doivent être définies."
  exit 1
fi

echo "=== Déploiement du Frontend Statique ==="
echo "Bucket cible : gs://${GCS_BUCKET}"

# Utiliser gcloud storage rsync pour synchroniser le dossier frontend
# Exclure le fichier mock pour le déploiement de production
gcloud storage rsync "${DIR}/../frontend/" "gs://${GCS_BUCKET}/" \
  --project="${GCP_PROJECT}" \
  --recursive \
  --delete-unmatched-destination-objects \
  --exclude=".*\.mock\.json$|data\.json$"

# Définir explicitement les types MIME pour les fichiers clés
echo "Configuration des en-têtes Content-Type..."
gcloud storage objects update "gs://${GCS_BUCKET}/index.html" --content-type="text/html" --project="${GCP_PROJECT}"
gcloud storage objects update "gs://${GCS_BUCKET}/style.css" --content-type="text/css" --project="${GCP_PROJECT}"
gcloud storage objects update "gs://${GCS_BUCKET}/app.js" --content-type="application/javascript" --project="${GCP_PROJECT}"

echo "Déploiement Frontend terminé avec succès !"
echo "Votre site est accessible à l'adresse : http://storage.googleapis.com/${GCS_BUCKET}/index.html"
