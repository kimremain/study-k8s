param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
    [string]$ImageTag
)

# 스크립트 위치(infra/scripts)를 기준으로 프로젝트 루트를 계산한다.
# 이후의 모든 상대 경로는 프로젝트 루트를 기준으로 해석된다.
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

$image = "kubewatch-backend:$ImageTag"
$archive = "tmp/kubewatch-backend-$ImageTag.tar"

# 백엔드 Docker 이미지를 롤백 가능한 고유 태그로 빌드한다.
docker build -t $image ./backend

# 이미지 빌드가 실패하면 이후 저장·가져오기 단계를 실행하지 않는다.
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# 빌드된 백엔드 이미지와 태그를 확인한다.
docker image inspect $image
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Docker 이미지를 Kubernetes 노드로 전달할 tar 파일로 저장한다.
New-Item -ItemType Directory -Force tmp | Out-Null
docker save $image -o $archive
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# PowerShell의 바이너리 파이프 대신 cmd의 입력 리다이렉션을 사용한다.
# Docker Desktop Kubernetes 노드의 containerd(k8s.io 네임스페이스)에 이미지를 등록한다.
cmd /c "docker exec -i desktop-control-plane ctr -n k8s.io images import - < $archive"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Kubernetes 노드의 containerd에 이미지가 등록됐는지 확인한다.
$registeredImages = docker exec desktop-control-plane ctr -n k8s.io images list
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
if ($registeredImages -notmatch [regex]::Escape($image)) {
    Write-Error "Kubernetes 노드에서 이미지를 찾을 수 없습니다: $image"
    exit 1
}
$registeredImages | Select-String ([regex]::Escape($image))

Write-Host "빌드 및 등록 완료: $image"
