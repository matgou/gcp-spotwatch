FROM python:3.12-slim

# Éviter l'écriture de fichiers .pyc sur disque et forcer le flush du stdout
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Installer les dépendances
COPY fetcher/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source et le dossier SQL
COPY fetcher/ /app/fetcher/
COPY sql/ /app/sql/

# Configurer le répertoire de travail et lancer le script depuis fetcher
WORKDIR /app/fetcher
CMD ["python", "main.py"]
