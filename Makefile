.PHONY: setup-infra deploy-frontend build-fetcher deploy-fetcher run-local help

# Gestion des environnements (par défaut: noprod)
ENV ?= noprod

# Charger le fichier d'environnement correspondant
ifneq (,$(wildcard ./.env.$(ENV)))
    include .env.$(ENV)
    export
endif

# Variables par défaut
REGION ?= europe-west1
REPO_NAME ?= spot-capacity-repo-noprod
JOB_NAME ?= spot-capacity-fetcher-noprod
SA_NAME ?= spot-fetcher-sa-noprod

help:
	@echo "Commandes disponibles (utilisez ENV=prod ou ENV=noprod) :"
	@echo "  make setup-infra      - Déploie l'infrastructure sur GCP via Terraform (Env: $(ENV))"
	@echo "  make deploy-frontend  - Téléverse le site statique sur GCS (Env: $(ENV))"
	@echo "  make build-fetcher    - Construit l'image Docker du fetcher localement"
	@echo "  make deploy-fetcher   - Soumet le build et déploie le Cloud Run Job (Env: $(ENV))"
	@echo "  make run-local        - Lance le collecteur Python localement (Env: $(ENV))"

setup-infra:
	cd infra && terraform init && terraform apply -var-file="$(ENV).tfvars"

deploy-frontend:
	@chmod +x scripts/deploy_frontend.sh
	./scripts/deploy_frontend.sh

build-fetcher:
	docker build -t $(REGION)-docker.pkg.dev/$(GCP_PROJECT)/$(REPO_NAME)/$(JOB_NAME):latest -f fetcher/Dockerfile fetcher

deploy-fetcher:
	@if [ -z "$(GCP_PROJECT)" ]; then echo "Erreur: GCP_PROJECT non défini dans le fichier .env"; exit 1; fi
	gcloud builds submit --config=fetcher/cloudbuild.yaml \
		--substitutions=_REGION=$(REGION),_REPO_NAME=$(REPO_NAME),_JOB_NAME=$(JOB_NAME),_SA_NAME=$(SA_NAME),_TAG=$$(git rev-parse --short HEAD 2>/dev/null || echo latest) \
		--project=$(GCP_PROJECT)

run-local:
	@if [ -z "$(GCP_PROJECT)" ]; then echo "Erreur: GCP_PROJECT non défini dans le fichier .env"; exit 1; fi
	python3 fetcher/main.py
