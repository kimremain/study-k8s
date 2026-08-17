param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
  [string]$ImageTag
)

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$namespace = "kubewatch"
$runtimeOverlay = Join-Path $projectRoot "tmp\kustomize-fullstack-local"
$runtimeKustomization = Join-Path $runtimeOverlay "kustomization.yaml"
$backendImage = "kubewatch-backend:$ImageTag"
$frontendImage = "kubewatch-frontend:$ImageTag"

$registeredImages = docker exec desktop-control-plane ctr -n k8s.io images list
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

foreach ($image in @($backendImage, $frontendImage)) {
  if (-not ($registeredImages | Select-String -SimpleMatch $image -Quiet)) {
    Write-Error "Image not found in Kubernetes node: $image"
    exit 1
  }
}
New-Item -ItemType Directory -Force $runtimeOverlay | Out-Null

@"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../infra/k8s/overlays/local
images:
  - name: kubewatch-backend
    newTag: $ImageTag
  - name: kubewatch-frontend
    newTag: $ImageTag
"@ | Set-Content -Path $runtimeKustomization -Encoding utf8

Write-Host "Rendering Kubernetes resources"
kubectl kustomize $runtimeOverlay
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host "Running client-side dry run"
kubectl apply --dry-run=client -k $runtimeOverlay
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host "Applying Kubernetes resources"
kubectl apply -k $runtimeOverlay
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

kubectl rollout status deployment/kubewatch-backend-local `
  -n $namespace `
  --timeout=120s
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

kubectl rollout status deployment/kubewatch-frontend-local `
  -n $namespace `
  --timeout=120s
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
$actualBackendImage = kubectl get deployment kubewatch-backend-local `
  -n $namespace `
  -o jsonpath="{.spec.template.spec.containers[0].image}"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$actualFrontendImage = kubectl get deployment kubewatch-frontend-local `
  -n $namespace `
  -o jsonpath="{.spec.template.spec.containers[0].image}"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
if ($actualBackendImage -ne $backendImage) {
  Write-Error "Unexpected backend image: $actualBackendImage"
  exit 1
}

if ($actualFrontendImage -ne $frontendImage) {
  Write-Error "Unexpected frontend image: $actualFrontendImage"
  exit 1
}

kubectl get deployments,pods,services,ingresses -n $namespace
kubectl get endpointslice -n $namespace

Write-Host "Deployment completed"
Write-Host "Backend:  $actualBackendImage"
Write-Host "Frontend: $actualFrontendImage"
