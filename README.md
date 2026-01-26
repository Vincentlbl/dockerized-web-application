# Projet d'Application Web Dockerisée

Ce projet a pour objectif de conteneuriser une application web complète (front-end, API, base de données) en utilisant Docker et Docker Compose, afin de garantir un déploiement reproductible et isolé sur n'importe quelle machine.

## 1. Schéma d'Architecture

Le schéma ci-dessous présente l'architecture multi-conteneurs de l'application, les réseaux, les volumes et les flux de communication principaux.

![Schéma d'architecture Docker](architecture_docker.png)

## 2. Prérequis

- **Docker Engine** : version `20.10.0` ou supérieure
- **Docker Compose** : version `v2.0.0` ou supérieure
- **Système d'exploitation** : Linux, Windows (avec WSL2) ou macOS
- **Git** : pour cloner le dépôt
- **OpenSSL** ou **mkcert** : pour générer les certificats TLS

## 3. Procédure de Déploiement

### 3.1. Configuration Initiale

1.  **Cloner le dépôt :**
    ```bash
    git clone https://github.com/Vincentlbl/dockerized-web-application.git
    cd dockerized-web-application
    ```

2.  **Créer le fichier d'environnement :**
    Copiez le fichier `.env.example` et renommez-le en `.env`. Ce fichier centralise toutes les variables de configuration.
    ```bash
    cp .env.example .env
    ```

3.  **Générer les secrets :**
    Modifiez le fichier `.env` et remplacez les valeurs par défaut (comme `change_me_secret`) par des secrets forts. Vous pouvez utiliser la commande suivante pour générer des chaînes de caractères aléatoires :
    ```bash
    openssl rand -base64 32
    ```

4.  **Générer les certificats TLS :**
    Pour la communication HTTPS, vous devez générer un certificat et une clé privée. Placez-les dans le dossier `certs/`.
    ```bash
    # Exemple avec openssl
    MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:4096 \
      -keyout certs/dev.key \
      -out certs/dev.cert \
      -days 365 \
      -nodes \
      -subj "/CN=localhost"
    ```

### 3.2. Build et Lancement

Une fois la configuration terminée, lancez l'ensemble de la stack avec Docker Compose :

```bash
docker-compose up --build -d
```

- `--build` : force la reconstruction des images si les Dockerfiles ont changé.
- `-d` : lance les conteneurs en mode détaché (en arrière-plan).

### 3.3. Accès aux Services

- **Application Front-end** : `https://localhost:4173`
- **Gateway (API)** : `https://localhost:8443`
- **SonarQube (optionnel)** : `http://localhost:9000`

Pour lancer les services de sécurité (SonarQube), utilisez le profil `security` :
```bash
docker-compose --profile security up -d
```

### 3.4. Arrêt des Services

Pour arrêter tous les conteneurs :
```bash
docker-compose down
```

Pour arrêter et supprimer les volumes (attention, cela supprime les données) :
```bash
docker-compose down -v
```

## 4. Description des Services

| Service | Description | Ports Exposés | Réseau(x) |
| :--- | :--- | :--- | :--- |
| `front` | Interface utilisateur en React, servie par Nginx. | `4173` | `public` |
| `gateway` | Point d'entrée unique (Node.js/Express). Gère le routage, le TLS, le rate limiting. | `8443` (HTTPS), `8080` (HTTP) | `public`, `backend` |
| `auth-service` | Microservice (Node.js) pour l'authentification (JWT) et la gestion des utilisateurs. | - | `backend` |
| `api-service` | Microservice (Node.js) pour la logique métier (gestion des tickets). | - | `backend` |
| `db` | Base de données PostgreSQL pour la persistance des données. | - | `backend` |
| `sonarqube` | (Optionnel) Outil d'analyse de la qualité et de la sécurité du code. | `9000` | `backend` |

## 5. Architecture et Choix Techniques

### 5.1. Réseaux

- **`public`** : Réseau externe qui expose les services accessibles depuis le navigateur (Front-end, Gateway).
- **`backend`** : Réseau interne et isolé pour la communication entre les services back-end (API, BDD). La Gateway est le seul service ayant accès aux deux réseaux, agissant comme une passerelle sécurisée.

### 5.2. Persistance des Données

La persistance des données est garantie par l'utilisation de **volumes Docker nommés** :
- **`db-data`** : Stocke les données de la base de données PostgreSQL. Ce volume n'est pas supprimé lors d'un `docker-compose down`, ce qui préserve les données.
- **`sonar-data`** et **`sonar-extensions`** : Stockent les données et les plugins de SonarQube.

Le fichier `db/init.sql` est monté en lecture seule pour initialiser la base de données au premier lancement.

### 5.3. Sécurité et Bonnes Pratiques

- **Utilisateurs non-root** : Les Dockerfiles pour les services Node.js et Nginx créent et utilisent un utilisateur non-privilégié (`node` ou `nginx`) pour réduire la surface d'attaque en cas de compromission d'un conteneur.
- **Gestion des secrets** : Les secrets (mots de passe, clés JWT) ne sont pas codés en dur. Ils sont gérés via des variables d'environnement chargées depuis un fichier `.env` qui est ignoré par Git (via `.gitignore`).
- **Images minimales** : Utilisation d'images de base légères (ex: `postgres:15-alpine`, `node:18-alpine`) pour réduire la taille des images et la surface d'attaque.
- **Healthchecks** : Chaque service critique dispose d'un `healthcheck` pour s'assurer de son bon fonctionnement avant que les services dépendants ne démarrent.
- **Réseau interne** : Le réseau `backend` est marqué comme `internal: true`, ce qui empêche toute communication directe depuis l'extérieur vers les services back-end.

---

## 6. Déploiement Kubernetes

Cette section décrit comment déployer l'application sur un cluster Kubernetes au lieu de Docker Compose.

### 6.1. Prérequis Kubernetes

- **kubectl** : CLI Kubernetes installé et configuré
- **Cluster Kubernetes** : Minikube, Docker Desktop (avec Kubernetes activé), ou un cluster cloud (AKS, EKS, GKE)
- **Ingress Controller** : NGINX Ingress Controller

### 6.2. Architecture Kubernetes

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLUSTER KUBERNETES                            │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    Namespace: ticketing-app                        │  │
│  │                                                                    │  │
│  │  ┌─────────────┐    ┌─────────────────────────────────────────┐   │  │
│  │  │   Ingress   │───▶│              Services                   │   │  │
│  │  │  (nginx)    │    │  ┌─────────┐  ┌─────────┐  ┌─────────┐  │   │  │
│  │  └─────────────┘    │  │  front  │  │ gateway │  │   ...   │  │   │  │
│  │         │           │  └────┬────┘  └────┬────┘  └─────────┘  │   │  │
│  │         ▼           └───────┼────────────┼────────────────────┘   │  │
│  │  ┌─────────────────────────┐│            │                        │  │
│  │  │      Deployments        ││            │                        │  │
│  │  │  ┌───────┐ ┌───────┐   ││            │                        │  │
│  │  │  │ front │ │gateway│◀──┘│            │                        │  │
│  │  │  │ (2x)  │ │ (2x)  │    │            │                        │  │
│  │  │  └───────┘ └───┬───┘    │            │                        │  │
│  │  │                │        │            │                        │  │
│  │  │          ┌─────▼─────┐  │            │                        │  │
│  │  │          │           │  │            │                        │  │
│  │  │  ┌───────┴──┐  ┌─────┴────┐  ┌─────┐                          │  │
│  │  │  │auth-svc  │  │ api-svc  │  │ db  │                          │  │
│  │  │  │  (2x)    │  │  (2x)    │  │(1x) │                          │  │
│  │  │  └──────────┘  └──────────┘  └──┬──┘                          │  │
│  │  └─────────────────────────────────┼─────────────────────────────┘  │
│  │                                    │                               │  │
│  │                              ┌─────▼─────┐                         │  │
│  │                              │    PVC    │                         │  │
│  │                              │  db-data  │                         │  │
│  │                              └───────────┘                         │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

### 6.3. Structure des Manifestes

```
k8s/
├── namespace.yaml           # Namespace dédié à l'application
├── secrets.yaml             # Secrets (DB credentials, JWT keys)
├── configmaps.yaml          # Configuration des services
├── db-deployment.yaml       # PostgreSQL (Deployment + Service + PVC)
├── auth-service-deployment.yaml  # Service d'authentification
├── api-service-deployment.yaml   # Service API
├── gateway-deployment.yaml       # Gateway/API Gateway
├── front-deployment.yaml         # Frontend React/Nginx
├── ingress.yaml             # Ingress pour l'exposition externe
├── hpa.yaml                 # Horizontal Pod Autoscaler
├── network-policies.yaml    # Politiques réseau pour la sécurité
├── kustomization.yaml       # Kustomize pour le déploiement
├── deploy.bat               # Script de déploiement Windows
├── deploy.sh                # Script de déploiement Linux/Mac
└── cleanup.bat              # Script de nettoyage
```

### 6.4. Installation de l'Ingress Controller

**Pour Minikube :**
```bash
minikube addons enable ingress
```

**Pour Docker Desktop :**
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

**Pour Metrics Server (requis pour HPA) :**
```bash
# Minikube
minikube addons enable metrics-server

# Autres
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### 6.5. Déploiement

#### Option 1 : Script automatique (Windows)
```cmd
cd k8s
deploy.bat
```

#### Option 2 : Script automatique (Linux/Mac)
```bash
cd k8s
chmod +x deploy.sh
./deploy.sh
```

#### Option 3 : Déploiement manuel
```bash
# 1. Construire les images Docker
docker build -t auth-service:latest ./auth-service
docker build -t api-service:latest ./api-service
docker build -t gateway:latest ./gateway
docker build -t front:latest ./front

# 2. Pour Minikube, charger les images
minikube image load auth-service:latest
minikube image load api-service:latest
minikube image load gateway:latest
minikube image load front:latest

# 3. Appliquer les manifestes avec Kustomize
kubectl apply -k k8s/

# OU appliquer les manifestes un par un
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmaps.yaml
kubectl apply -f k8s/db-deployment.yaml
kubectl apply -f k8s/auth-service-deployment.yaml
kubectl apply -f k8s/api-service-deployment.yaml
kubectl apply -f k8s/gateway-deployment.yaml
kubectl apply -f k8s/front-deployment.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/network-policies.yaml
```

### 6.6. Accès à l'Application

**Pour Minikube :**
```bash
# Démarrer le tunnel (dans un terminal séparé)
minikube tunnel

# L'application est accessible sur http://localhost
```

**Pour Docker Desktop :**
```bash
# L'application est directement accessible sur http://localhost
```

### 6.7. Commandes Utiles

```bash
# Voir l'état des pods
kubectl get pods -n ticketing-app

# Voir les logs d'un pod
kubectl logs -f <nom-du-pod> -n ticketing-app

# Voir l'état des services
kubectl get svc -n ticketing-app

# Voir l'état de l'Ingress
kubectl get ingress -n ticketing-app

# Voir l'état des HPA (auto-scaling)
kubectl get hpa -n ticketing-app

# Accéder à un pod en mode shell
kubectl exec -it <nom-du-pod> -n ticketing-app -- /bin/sh

# Supprimer toutes les ressources
kubectl delete -k k8s/
```

### 6.8. Fonctionnalités Kubernetes Avancées

#### Auto-scaling (HPA)
Les services `auth-service`, `api-service`, `gateway` et `front` sont configurés avec un **Horizontal Pod Autoscaler** qui :
- Maintient un minimum de 2 réplicas
- Scale jusqu'à 10 réplicas pour les services backend
- Se déclenche quand l'utilisation CPU dépasse 70%

```bash
# Voir l'état de l'auto-scaling
kubectl get hpa -n ticketing-app

# Simuler une charge pour tester l'auto-scaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://gateway:8080/health; done"
```

#### Rolling Updates
Les déploiements utilisent la stratégie **RollingUpdate** avec :
- `maxSurge: 1` : Au maximum 1 pod supplémentaire pendant la mise à jour
- `maxUnavailable: 0` : Toujours au moins le nombre de replicas disponibles

```bash
# Mettre à jour une image
kubectl set image deployment/api-service api-service=api-service:v2 -n ticketing-app

# Voir l'état du rollout
kubectl rollout status deployment/api-service -n ticketing-app

# Rollback si nécessaire
kubectl rollout undo deployment/api-service -n ticketing-app
```

#### Network Policies
Les **Network Policies** implémentent le principe du moindre privilège :
- Deny all par défaut
- Frontend accessible depuis l'Ingress uniquement
- Gateway accessible depuis l'Ingress et peut communiquer avec auth/api services
- Base de données accessible uniquement depuis auth-service et api-service

### 6.9. Justification : Base de Données Interne vs Externe

La base de données PostgreSQL est **déployée dans le cluster** pour les raisons suivantes :

| Avantages DB Interne | Inconvénients |
|---------------------|---------------|
| ✅ Simplicité de déploiement | ❌ Gestion manuelle des backups |
| ✅ Latence minimale (intra-cluster) | ❌ Scaling vertical limité |
| ✅ Isolation complète du réseau | ❌ Pas de haute disponibilité native |
| ✅ Coût réduit (dev/test) | ❌ Maintenance à gérer |

**Recommandation pour la production :**
Utiliser une base de données managée (Azure Database for PostgreSQL, Amazon RDS, Google Cloud SQL) pour bénéficier de :
- Backups automatiques
- Haute disponibilité
- Scaling automatique
- Maintenance gérée par le provider

### 6.10. Nettoyage

```bash
# Windows
k8s\cleanup.bat

# Linux/Mac
kubectl delete -k k8s/
```
