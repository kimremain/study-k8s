param(
# Use one release tag for both backend and frontend images.
  [Parameter(Mandatory = $true)]
  [ValidatePattern("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$")]
  [string]$ImageTag
)

# Resolve paths from this script so it works from any current directory.
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$tmpDirectory = Join-Path $projectRoot "tmp"
# Docker image archives are stored here before node import.
New-Item -ItemType Directory -Force $tmpDirectory | Out-Null

# Build one Docker image and import it into the Kubernetes node containerd.
function Build-AndImportImage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ImageName,

    [Parameter(Mandatory = $true)]
    [string]$BuildContext
  )

  # Create the full image name and a filesystem-safe archive name.
  $image = "${ImageName}:$ImageTag"
  $archiveName = ($image -replace "[:/]", "-") + ".tar"
  $archive = Join-Path $tmpDirectory $archiveName

  # Build the image using the requested release tag.
  Write-Host "Building image: $image"
  docker build -t $image $BuildContext
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  # Confirm that Docker registered the image locally.
  docker image inspect $image | Out-Null
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  # Export the image because the Kubernetes node uses its own containerd.
  Write-Host "Saving image: $archive"
  docker save $image -o $archive
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  # Stream the archive into the Docker Desktop Kubernetes node.
  # cmd.exe is used because PowerShell does not support this '<' redirection.
  Write-Host "Importing image into Kubernetes node: $image"
  $importCommand = 'docker exec -i desktop-control-plane ctr -n k8s.io images import - < "{0}"' -f $archive
  cmd.exe /d /c $importCommand
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  # Read the node image inventory after the import.
  $registeredImages = docker exec desktop-control-plane ctr -n k8s.io images list
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  # Fail early if the node cannot find the exact image and tag.
  if (-not ($registeredImages | Select-String -SimpleMatch $image -Quiet)) {
    Write-Error "Image not found in Kubernetes node: $image"
    exit 1
  }

  # Print the matching inventory entry as evidence of a successful import.
  $registeredImages | Select-String -SimpleMatch $image
}

# Build and import the backend image.
Build-AndImportImage `
  -ImageName "kubewatch-backend" `
  -BuildContext (Join-Path $projectRoot "backend")

# Build and import the frontend image.
Build-AndImportImage `
  -ImageName "kubewatch-frontend" `
  -BuildContext (Join-Path $projectRoot "frontend")

Write-Host "Build and import completed: $ImageTag"
