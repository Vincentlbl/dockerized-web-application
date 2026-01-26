@echo off
REM =============================================================================
REM Script de déploiement Kubernetes pour l'application Ticketing (Windows)
REM =============================================================================

setlocal enabledelayedexpansion

set NAMESPACE=ticketing-app
set SCRIPT_DIR=%~dp0

echo ==========================================
echo   Deploiement Kubernetes - Ticketing App
echo ==========================================

REM Vérifier si kubectl est disponible
where kubectl >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [X] kubectl n'est pas installe. Veuillez l'installer d'abord.
    exit /b 1
)

REM Vérifier la connexion au cluster
echo [?] Verification de la connexion au cluster Kubernetes...
kubectl cluster-info >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [X] Impossible de se connecter au cluster Kubernetes.
    echo     Assurez-vous que Minikube ou Docker Desktop Kubernetes est demarre.
    exit /b 1
)

echo [OK] Connecte au cluster Kubernetes

REM Build des images Docker
echo.
echo [Docker] Construction des images Docker...
cd /d "%SCRIPT_DIR%.."

docker build -t auth-service:latest ./auth-service
docker build -t api-service:latest ./api-service
docker build -t gateway:latest ./gateway
docker build -t front:latest ./front

echo [OK] Images Docker construites

REM Si Minikube, charger les images dans Minikube
where minikube >nul 2>nul
if %ERRORLEVEL% equ 0 (
    minikube status >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        echo.
        echo [Minikube] Chargement des images dans Minikube...
        minikube image load auth-service:latest
        minikube image load api-service:latest
        minikube image load gateway:latest
        minikube image load front:latest
        echo [OK] Images chargees dans Minikube
    )
)

REM Appliquer les manifestes Kubernetes
echo.
echo [K8s] Deploiement des manifestes Kubernetes...
cd /d "%SCRIPT_DIR%"

REM 1. Namespace
echo   - Creation du namespace...
kubectl apply -f namespace.yaml

REM 2. Secrets et ConfigMaps
echo   - Creation des secrets et configmaps...
kubectl apply -f secrets.yaml
kubectl apply -f configmaps.yaml

REM 3. Base de données
echo   - Deploiement de la base de donnees...
kubectl apply -f db-deployment.yaml

REM Attendre que la base de données soit prête
echo   - Attente de la disponibilite de la base de donnees...
kubectl wait --namespace=%NAMESPACE% --for=condition=ready pod -l app=db --timeout=120s

REM 4. Services backend
echo   - Deploiement des services backend...
kubectl apply -f auth-service-deployment.yaml
kubectl apply -f api-service-deployment.yaml

REM Attendre que les services backend soient prêts
echo   - Attente de la disponibilite des services backend...
kubectl wait --namespace=%NAMESPACE% --for=condition=ready pod -l app=auth-service --timeout=120s
kubectl wait --namespace=%NAMESPACE% --for=condition=ready pod -l app=api-service --timeout=120s

REM 5. Gateway
echo   - Deploiement du gateway...
kubectl apply -f gateway-deployment.yaml
kubectl wait --namespace=%NAMESPACE% --for=condition=ready pod -l app=gateway --timeout=120s

REM 6. Frontend
echo   - Deploiement du frontend...
kubectl apply -f front-deployment.yaml
kubectl wait --namespace=%NAMESPACE% --for=condition=ready pod -l app=front --timeout=120s

REM 7. Ingress
echo   - Configuration de l'Ingress...
kubectl apply -f ingress.yaml

REM 8. HPA (optionnel)
echo   - Configuration de l'auto-scaling (HPA)...
kubectl apply -f hpa.yaml

REM 9. Network Policies (optionnel)
echo   - Configuration des Network Policies...
kubectl apply -f network-policies.yaml

echo.
echo ==========================================
echo   [OK] Deploiement termine avec succes!
echo ==========================================
echo.
echo [Info] Etat des pods:
kubectl get pods -n %NAMESPACE%
echo.
echo [Info] Services:
kubectl get services -n %NAMESPACE%
echo.
echo [Info] Ingress:
kubectl get ingress -n %NAMESPACE%
echo.
echo ==========================================
echo   Acces a l'application
echo ==========================================
echo.
echo Pour Minikube:
echo   minikube tunnel
echo   Puis accedez a: http://localhost
echo.
echo Pour Docker Desktop:
echo   Accedez directement a: http://localhost
echo.

endlocal
