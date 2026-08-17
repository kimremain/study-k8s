param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
  [string]$ImageTag
)

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$tmpDirectory = Join-Path $projectRoot "tmp"

New-Item -ItemType Directory -Force $tmpDirectory | Out-Null

function Build-AndImportImage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ImageName,

    [Parameter(Mandatory = $true)]
    [string]$BuildContext
  )

  $image = "${ImageName}:$ImageTag"
  $archiveName = ($image -replace "[:/]", "-") + ".tar"
  $archive = Join-Path $tmpDirectory $archiveName

  Write-Host "Building image: $image"
  docker build -t $image $BuildContext
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  docker image inspect $image | Out-Null
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  Write-Host "Saving image: $archive"
  docker save $image -o $archive
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  Write-Host "Importing image into Kubernetes node: $image"
  $importCommand = 'docker exec -i desktop-control-plane ctr -n k8s.io images import - < "{0}"' -f $archive
  cmd.exe /d /c $importCommand
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  $registeredImages = docker exec desktop-control-plane ctr -n k8s.io images list
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  if (-not ($registeredImages | Select-String -SimpleMatch $image -Quiet)) {
    Write-Error "Image not found in Kubernetes node: $image"
    exit 1
  }
  $registeredImages | Select-String -SimpleMatch $image
}

Build-AndImportImage `
  -ImageName "kubewatch-backend" `
  -BuildContext (Join-Path $projectRoot "backend")

Build-AndImportImage `
  -ImageName "kubewatch-frontend" `
  -BuildContext (Join-Path $projectRoot "frontend")

Write-Host "Build and import completed: $ImageTag"
