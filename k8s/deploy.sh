#!/bin/bash
# =============================================================================
# Script de déploiement Kubernetes pour l'application Ticketing
# =============================================================================

set -e

NAMESPACE="ticketing-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  Déploiement Kubernetes - Ticketing App"
echo "=========================================="

# Vérifier si kubectl est disponible
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl n'est pas installé. Veuillez l'installer d'abord."
    exit 1
fi

# Vérifier la connexion au cluster
echo "🔍 Vérification de la connexion au cluster Kubernetes..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Impossible de se connecter au cluster Kubernetes."
    echo "   Assurez-vous que Minikube ou Docker Desktop Kubernetes est démarré."
    exit 1
fi

echo "✅ Connecté au cluster Kubernetes"

# Build des images Docker
echo ""
echo "🐳 Construction des images Docker..."
cd "$SCRIPT_DIR/.."

docker build -t auth-service:latest ./auth-service
docker build -t api-service:latest ./api-service
docker build -t gateway:latest ./gateway
docker build -t front:latest ./front

echo "✅ Images Docker construites"

# Si Minikube, charger les images dans Minikube
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo ""
    echo "📦 Chargement des images dans Minikube..."
    minikube image load auth-service:latest
    minikube image load api-service:latest
    minikube image load gateway:latest
    minikube image load front:latest
    echo "✅ Images chargées dans Minikube"
fi

# Appliquer les manifestes Kubernetes
echo ""
echo "🚀 Déploiement des manifestes Kubernetes..."
cd "$SCRIPT_DIR"

# 1. Namespace
echo "  → Création du namespace..."
kubectl apply -f namespace.yaml

# 2. Secrets et ConfigMaps
echo "  → Création des secrets et configmaps..."
kubectl apply -f secrets.yaml
kubectl apply -f configmaps.yaml

# 3. Base de données
echo "  → Déploiement de la base de données..."
kubectl apply -f db-deployment.yaml

# Attendre que la base de données soit prête
echo "  → Attente de la disponibilité de la base de données..."
kubectl wait --namespace=$NAMESPACE --for=condition=ready pod -l app=db --timeout=120s

# 4. Services backend
echo "  → Déploiement des services backend..."
kubectl apply -f auth-service-deployment.yaml
kubectl apply -f api-service-deployment.yaml

# Attendre que les services backend soient prêts
echo "  → Attente de la disponibilité des services backend..."
kubectl wait --namespace=$NAMESPACE --for=condition=ready pod -l app=auth-service --timeout=120s
kubectl wait --namespace=$NAMESPACE --for=condition=ready pod -l app=api-service --timeout=120s

# 5. Gateway
echo "  → Déploiement du gateway..."
kubectl apply -f gateway-deployment.yaml
kubectl wait --namespace=$NAMESPACE --for=condition=ready pod -l app=gateway --timeout=120s

# 6. Frontend
echo "  → Déploiement du frontend..."
kubectl apply -f front-deployment.yaml
kubectl wait --namespace=$NAMESPACE --for=condition=ready pod -l app=front --timeout=120s

# 7. Ingress
echo "  → Configuration de l'Ingress..."
kubectl apply -f ingress.yaml

# 8. HPA (optionnel)
echo "  → Configuration de l'auto-scaling (HPA)..."
kubectl apply -f hpa.yaml || echo "⚠️  HPA non appliqué (metrics-server peut être manquant)"

# 9. Network Policies (optionnel)
echo "  → Configuration des Network Policies..."
kubectl apply -f network-policies.yaml || echo "⚠️  Network Policies non appliquées"

echo ""
echo "=========================================="
echo "  ✅ Déploiement terminé avec succès!"
echo "=========================================="
echo ""
echo "📊 État des pods:"
kubectl get pods -n $NAMESPACE
echo ""
echo "🌐 Services:"
kubectl get services -n $NAMESPACE
echo ""
echo "🔗 Ingress:"
kubectl get ingress -n $NAMESPACE
echo ""
echo "=========================================="
echo "  📝 Accès à l'application"
echo "=========================================="
echo ""
echo "Pour Minikube:"
echo "  minikube tunnel"
echo "  Puis accédez à: http://localhost"
echo ""
echo "Pour Docker Desktop:"
echo "  Accédez directement à: http://localhost"
echo ""
