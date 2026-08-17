param(
# Deploy the same release tag for both application components.
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
  [string]$ImageTag
)

# Resolve paths independently of the caller's current directory.
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$namespace = "kubewatch"

# Generate a temporary overlay instead of modifying tracked manifests.
$runtimeOverlay = Join-Path $projectRoot "tmp\kustomize-fullstack-local"
$runtimeKustomization = Join-Path $runtimeOverlay "kustomization.yaml"

# These are the exact image references expected after deployment.
$backendImage = "kubewatch-backend:$ImageTag"
$frontendImage = "kubewatch-frontend:$ImageTag"

# Check the Kubernetes node image inventory before changing the cluster.
$registeredImages = docker exec desktop-control-plane ctr -n k8s.io images list
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Both images must already have been imported by build-local.ps1.
foreach ($image in @($backendImage, $frontendImage)) {
  if (-not ($registeredImages | Select-String -SimpleMatch $image -Quiet)) {
    Write-Error "Image not found in Kubernetes node: $image"
    exit 1
  }
}

# Create or reuse the temporary runtime overlay directory.
New-Item -ItemType Directory -Force $runtimeOverlay | Out-Null

# Extend the tracked local overlay and replace both image tags at runtime.
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

# Render the final YAML and stop if the Kustomize configuration is invalid.
Write-Host "Rendering Kubernetes resources"
kubectl kustomize $runtimeOverlay
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Validate the apply request locally before changing cluster resources.
Write-Host "Running client-side dry run"
kubectl apply --dry-run=client -k $runtimeOverlay
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Reconcile the rendered resources with the Kubernetes cluster.
Write-Host "Applying Kubernetes resources"
kubectl apply -k $runtimeOverlay
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Wait until the backend Deployment completes its rolling update.
kubectl rollout status deployment/kubewatch-backend-local `
  -n $namespace `
  --timeout=120s
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Wait until the frontend Deployment completes its rolling update.
kubectl rollout status deployment/kubewatch-frontend-local `
  -n $namespace `
  --timeout=120s
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Read the image recorded in the backend Pod template.
$actualBackendImage = kubectl get deployment kubewatch-backend-local `
  -n $namespace `
  -o jsonpath="{.spec.template.spec.containers[0].image}"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Read the image recorded in the frontend Pod template.
$actualFrontendImage = kubectl get deployment kubewatch-frontend-local `
  -n $namespace `
  -o jsonpath="{.spec.template.spec.containers[0].image}"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Verify that Kustomize applied the requested backend tag.
if ($actualBackendImage -ne $backendImage) {
  Write-Error "Unexpected backend image: $actualBackendImage"
  exit 1
}

# Verify that Kustomize applied the requested frontend tag.
if ($actualFrontendImage -ne $frontendImage) {
  Write-Error "Unexpected frontend image: $actualFrontendImage"
  exit 1
}

# Print workload, networking, and endpoint state for final inspection.
kubectl get deployments,pods,services,ingresses -n $namespace
kubectl get endpointslice -n $namespace
Write-Host "Deployment completed"
Write-Host "Backend:  $actualBackendImage"
Write-Host "Frontend: $actualFrontendImage"
