# Spécifications : Frontend & Hébergement Statique

## 1. Hébergement sur Cloud Storage (GCS)
Le site doit être hébergé sous forme de site web statique directement depuis un bucket GCS.
- **Création du Bucket** : Créer un bucket Cloud Storage avec un nom de domaine valide (ex: `capacity.mon-domaine.com`).
- **Configuration Website** : Configurer la page principale sur `index.html` et la page d'erreur sur `404.html`.
- **Permissions** : Accorder le rôle IAM "Lecteur des objets de l'espace de stockage" (`roles/storage.objectViewer`) à `allUsers` pour rendre les fichiers publiquement lisibles.
- **CORS** : Si les données JSON sont dans un autre bucket, configurer les règles CORS. Ici, le JSON sera dans le même bucket, donc pas de problème de CORS.

## 2. Structure des Fichiers
```text
/
├── index.html        # Page principale contenant la structure et l'inclusion des scripts
├── style.css         # Styles minimalistes (Vanilla CSS) pour l'affichage
├── app.js            # Logique métier : récupération du JSON et configuration du graphique
└── data.json         # (Généré automatiquement par le backend) Les données temporelles
```

## 3. Technologies Frontend
- **HTML5 / CSS3** : Vanilla CSS pour une interface légère, moderne (Mode Sombre, typographie lisible type Google Sans ou Roboto).
- **JavaScript (Vanilla)** : Utilisation de l'API `fetch()` pour récupérer le `data.json`.
- **Librairie de Graphiques** : Utilisation de **Google Charts** (pour rester dans l'écosystème Google) ou **Chart.js** (pour la flexibilité et la réactivité).
  - *Recommandation :* Chart.js est généralement plus adapté pour des graphiques temporels (Line charts) modernes et responsives sur mobile.

## 4. Fonctionnalités Attendues (Interface)
1. **Header** : Titre du tableau de bord "GCP Spot VM Capacity Tracker" et date de dernière mise à jour (extraite du `data.json`).
2. **Filtres (Optionnels mais recommandés)** : Sélecteurs natifs (dropdowns) permettant de filtrer par `Région` ou par `Type de Machine`.
3. **Graphique Linéaire (Line Chart)** :
   - **Axe X** : Temps (Heures / Jours).
   - **Axe Y** : Score de disponibilité (De 0.0 à 1.0).
   - **Lignes** : Une ligne par type de machine / région.
4. **Lien vers BigQuery** : Un bouton "Explorer les données brutes" redirigeant vers l'interface BigQuery pointant sur le dataset public.
