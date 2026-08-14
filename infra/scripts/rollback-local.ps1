param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
    [string]$ImageTag
)

$deployment = "deployment/kubewatch-backend-local"
$namespace = "kubewatch"

# 현재 revision과 이미지를 확인한 후, 이전에 검증한 이미지 태그를 선언적으로 다시 적용한다.
kubectl rollout history $deployment -n $namespace
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

kubectl get $deployment -n $namespace -o jsonpath="현재 이미지: {.spec.template.spec.containers[*].image}"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
Write-Host ""
Write-Host "롤백 대상 이미지: kubewatch-backend:$ImageTag"

# deploy-local과 같은 Kustomize 경로를 사용해 last-applied-configuration도 함께 갱신한다.
& (Join-Path $PSScriptRoot "deploy-local.ps1") -ImageTag $ImageTag -SkipPortForward
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "롤백 완료: kubewatch-backend:$ImageTag"
