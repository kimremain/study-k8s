param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
    [string]$ImageTag
)

# 스크립트 위치(infra/scripts)를 기준으로 프로젝트 루트를 계산한다.
# 이후의 모든 상대 경로는 프로젝트 루트를 기준으로 해석된다.
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
Set-Location $projectRoot

# Kubernetes를 거치지 않고 백엔드 이미지를 Docker 컨테이너로 직접 실행한다.
# --rm: 종료 시 컨테이너 자동 삭제
# --name: 확인하기 쉬운 고정 컨테이너 이름 지정
# -p: 호스트 8005 포트를 컨테이너 8000 포트에 연결
docker run --rm `
    --name kubewatch-backend `
    -p 8005:8000 `
    "kubewatch-backend:$ImageTag"

# 컨테이너 실행 중 사용할 수 있는 확인 주소:
# Swagger:   http://localhost:8005/docs
# Health:    http://localhost:8005/healthz
# Readiness: http://localhost:8005/readyz
