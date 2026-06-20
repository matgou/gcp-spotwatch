FROM python:3.12-slim

# Éviter l'écriture de fichiers .pyc sur disque et forcer le flush du stdout
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Installer les dépendances
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source et le fichier SQL
COPY . .

# Lancement du script
CMD ["python", "main.py"]
