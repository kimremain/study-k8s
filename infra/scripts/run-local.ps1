$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

docker run --rm `
    --name kubewatch-backend `
    -p 8005:8000 `
    kubewatch-backend:local

#Swagger: http://localhost:8005/docs
#Health: http://localhost:8005/healthz
#Readiness: http://localhost:8005/readyz
