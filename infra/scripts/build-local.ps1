$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

docker build -t kubewatch-backend:local ./backend

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

docker images kubewatch-backend

docker save kubewatch-backend:local -o tmp/kubewatch-backend-local.tar

cmd /c "docker exec -i desktop-control-plane ctr -n k8s.io images import - < tmp\kubewatch-backend-local.tar"

docker exec desktop-control-plane ctr -n k8s.io images list | Select-String kubewatch-backend
