# 스크립트 위치(infra/scripts)를 기준으로 프로젝트 루트를 계산한다.
# 이후의 모든 상대 경로는 프로젝트 루트를 기준으로 해석된다.
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

#kubectl rollout status deployment/kubewatch-backend-local -n kubewatch
#kubectl rollout history deployment/kubewatch-backend-local -n kubewatch

kubectl rollout undo deployment/kubewatch-backend-local -n kubewatch
