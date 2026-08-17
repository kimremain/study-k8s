param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
  [string]$ImageTag,
  [ValidateRange(1, 65535)]
  [int]$LocalPort = 8060,

  [switch]$SkipBuild
)

$buildScript = Join-Path $PSScriptRoot "build-local.ps1"
$deployScript = Join-Path $PSScriptRoot "deploy-local.ps1"

if (-not $SkipBuild) {
  Write-Host "Building full stack: $ImageTag"
  & $buildScript -ImageTag $ImageTag
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

Write-Host "Deploying full stack: $ImageTag"
& $deployScript -ImageTag $ImageTag
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "KubeWatch is ready."
Write-Host "URL: http://kubewatch.local:$LocalPort/"
Write-Host "API: http://kubewatch.local:$LocalPort/api/v1/status"
Write-Host "Press Ctrl+C to stop port forwarding."
Write-Host ""
kubectl port-forward `
  -n ingress-nginx `
  service/ingress-nginx-controller `
  "${LocalPort}:80"

exit $LASTEXITCODE
