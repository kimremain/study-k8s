param(
  [SecureString]$DatabasePassword
)

$namespace = "kubewatch"
$secretName = "kubewatch-database-secret"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if ($null -eq $DatabasePassword) {
  $DatabasePassword = Read-Host "Enter the local PostgreSQL password" -AsSecureString
}

$plainDatabasePassword = [System.Net.NetworkCredential]::new(
  "",
  $DatabasePassword
).Password

if ([string]::IsNullOrWhiteSpace($plainDatabasePassword)) {
  Write-Error "Database password must not be empty."
  exit 1
}

try {
  # Make first-time bootstrap possible before the complete overlay is applied.
  kubectl apply -f (Join-Path $projectRoot "infra\k8s\base\namespace.yaml")
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  $secretManifest = @{
    apiVersion = "v1"
    kind = "Secret"
    metadata = @{
      name = $secretName
      namespace = $namespace
      labels = @{
        "app.kubernetes.io/name" = "kubewatch-postgres"
        "app.kubernetes.io/part-of" = "kubewatch"
      }
    }
    type = "Opaque"
    stringData = @{
      KUBEWATCH_DATABASE_PASSWORD = $plainDatabasePassword
    }
  } | ConvertTo-Json -Depth 5 -Compress

  $secretManifest | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  Write-Host "Local database Secret applied: $namespace/$secretName"
}
finally {
  $plainDatabasePassword = $null
  $secretManifest = $null
}
