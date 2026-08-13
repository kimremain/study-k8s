# 스크립트 위치(infra/scripts)를 기준으로 프로젝트 루트를 계산한다.
# 이후의 모든 상대 경로는 프로젝트 루트를 기준으로 해석된다.
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

# Kustomize가 최종 생성할 Kubernetes 리소스를 화면에서 먼저 확인한다.
kubectl kustomize infra/k8s/overlays/local

# local 오버레이에 정의된 리소스를 현재 Kubernetes 클러스터에 적용한다.
kubectl apply -k infra/k8s/overlays/local

# Deployment와 Pod의 배포 상태를 확인한다.
kubectl get deployments,pods -n kubewatch

# Service가 생성됐고 Pod 엔드포인트에 연결됐는지 확인한다.
kubectl get service,endpoints -n kubewatch

# 로컬 이미지를 다시 불러온 경우 새 Pod가 사용하도록 Deployment를 재시작한다.
kubectl rollout restart deployment/kubewatch-backend-local -n kubewatch
# 새 Pod가 준비될 때까지 롤아웃 완료를 기다린다.
kubectl rollout status deployment/kubewatch-backend-local -n kubewatch
# 최종 Pod 상태가 Ready 및 Running인지 확인한다.
kubectl get pods -n kubewatch

# 로컬 PC의 8005 포트를 Kubernetes Service의 8000 포트로 연결한다.
# 이 명령은 종료할 때까지 현재 PowerShell을 점유한다.
kubectl port-forward service/kubewatch-backend-local 8005:8000 -n kubewatch

# 포트 포워딩 중 사용할 수 있는 확인 주소:
# Swagger:   http://localhost:8005/docs
# Health:    http://localhost:8005/healthz
# Readiness: http://localhost:8005/readyz
