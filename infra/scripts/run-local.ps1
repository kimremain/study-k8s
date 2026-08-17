param(
# The release tag passed to both the build and deployment scripts.
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
  [string]$ImageTag,

# Local port exposed by kubectl port-forward.
  [ValidateRange(1, 65535)]
  [int]$LocalPort = 8060,

# Skip image rebuilding when the requested images already exist.
  [switch]$SkipBuild
)

# Resolve sibling scripts from this script's directory.
$buildScript = Join-Path $PSScriptRoot "build-local.ps1"
$deployScript = Join-Path $PSScriptRoot "deploy-local.ps1"

# Build and import both images unless the caller requests reuse.
if (-not $SkipBuild) {
  Write-Host "Building full stack: $ImageTag"
  & $buildScript -ImageTag $ImageTag
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

# Deploy both application components and wait for their rollouts.
Write-Host "Deploying full stack: $ImageTag"
& $deployScript -ImageTag $ImageTag
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Display the URLs before starting the blocking port-forward command.
Write-Host ""
Write-Host "KubeWatch is ready."
Write-Host "URL: http://kubewatch.local:$LocalPort/"
Write-Host "API: http://kubewatch.local:$LocalPort/api/v1/status"
Write-Host "Press Ctrl+C to stop port forwarding."
Write-Host ""

# Forward the local port to the ingress controller.
# The kubewatch.local Host header lets Ingress select the correct route.
kubectl port-forward `
  -n ingress-nginx `
  service/ingress-nginx-controller `
  "${LocalPort}:80"

# Return kubectl's exit code to the calling shell.
exit $LASTEXITCODE
