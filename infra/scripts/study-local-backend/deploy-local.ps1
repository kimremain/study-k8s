param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
    [string]$ImageTag,

    [switch]$SkipPortForward
)

# 스크립트 위치(infra/scripts)를 기준으로 프로젝트 루트를 계산한다.
# 이후의 모든 상대 경로는 프로젝트 루트를 기준으로 해석된다.
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
Set-Location $projectRoot

$deployment = "deployment/kubewatch-backend-local"
$namespace = "kubewatch"
$runtimeOverlay = Join-Path $projectRoot "tmp\kustomize-local"
$runtimeKustomization = Join-Path $runtimeOverlay "kustomization.yaml"

# 추적 중인 매니페스트는 바꾸지 않고, 선택한 이미지 태그를 덧씌우는 임시 오버레이를 만든다.
New-Item -ItemType Directory -Force $runtimeOverlay | Out-Null
@"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../infra/k8s/overlays/local
images:
  - name: kubewatch-backend
    newTag: $ImageTag
"@ | Set-Content -Path $runtimeKustomization -Encoding utf8

# Kustomize가 최종 생성할 Kubernetes 리소스를 화면에서 먼저 확인한다.
kubectl kustomize $runtimeOverlay
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# 선택한 불변 이미지 태그가 포함된 리소스를 현재 Kubernetes 클러스터에 적용한다.
kubectl apply -k $runtimeOverlay
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Deployment와 Pod의 배포 상태를 확인한다.
kubectl get deployments,pods -n $namespace
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Service가 생성됐고 Pod 엔드포인트에 연결됐는지 확인한다.
kubectl get service,endpoints -n $namespace
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# 이미지 태그 변경으로 생성된 새 Pod가 준비될 때까지 기다린다.
kubectl rollout status $deployment -n $namespace --timeout=120s
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# 최종 Pod 상태가 Ready 및 Running인지 확인한다.
kubectl get pods -n $namespace
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Deployment가 실제로 사용하는 이미지를 출력한다.
kubectl get $deployment -n $namespace -o jsonpath="{.spec.template.spec.containers[*].image}"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
Write-Host ""

# 로컬 PC의 8005 포트를 Kubernetes Service의 8000 포트로 연결한다.
# 이 명령은 종료할 때까지 현재 PowerShell을 점유한다.
if (-not $SkipPortForward) {
    kubectl port-forward service/kubewatch-backend-local 8005:8000 -n $namespace
}

# 포트 포워딩 중 사용할 수 있는 확인 주소:
# Swagger:   http://localhost:8005/docs
# Health:    http://localhost:8005/healthz
# Readiness: http://localhost:8005/readyz
