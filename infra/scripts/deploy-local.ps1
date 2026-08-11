$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

kubectl kustomize infra/k8s/overlays/local

kubectl apply -k infra/k8s/overlays/local

kubectl get deployments,pods -n kubewatch

kubectl get service,endpoints -n kubewatch

kubectl rollout restart deployment/kubewatch-backend-local -n kubewatch
kubectl rollout status deployment/kubewatch-backend-local -n kubewatch
kubectl get pods -n kubewatch

kubectl port-forward service/kubewatch-backend-local 8005:8000 -n kubewatch

#Swagger: http://localhost:8005/docs
#Health: http://localhost:8005/healthz
#Readiness: http://localhost:8005/readyz
