@echo off
REM =============================================================================
REM Script de suppression des ressources Kubernetes (Windows)
REM =============================================================================

set NAMESPACE=ticketing-app

echo ==========================================
echo   Suppression des ressources Kubernetes
echo ==========================================

echo.
echo [!] Cette action va supprimer tous les deploiements de l'application.
echo.
set /p confirm="Etes-vous sur de vouloir continuer? (o/n): "
if /i not "%confirm%"=="o" (
    echo Annule.
    exit /b 0
)

echo.
echo [K8s] Suppression des ressources...

kubectl delete -f ingress.yaml --ignore-not-found
kubectl delete -f hpa.yaml --ignore-not-found
kubectl delete -f network-policies.yaml --ignore-not-found
kubectl delete -f front-deployment.yaml --ignore-not-found
kubectl delete -f gateway-deployment.yaml --ignore-not-found
kubectl delete -f api-service-deployment.yaml --ignore-not-found
kubectl delete -f auth-service-deployment.yaml --ignore-not-found
kubectl delete -f db-deployment.yaml --ignore-not-found
kubectl delete -f configmaps.yaml --ignore-not-found
kubectl delete -f secrets.yaml --ignore-not-found
kubectl delete -f namespace.yaml --ignore-not-found

echo.
echo [OK] Ressources Kubernetes supprimees.
