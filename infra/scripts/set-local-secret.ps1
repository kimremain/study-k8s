param(
  [SecureString]$ApiKey
)

$namespace = "kubewatch"
$secretName = "kubewatch-backend-secret"

# Prompt without displaying or storing the value in shell history.
if ($null -eq $ApiKey) {
  $ApiKey = Read-Host "Enter the local KubeWatch API key" -AsSecureString
}

# Kubernetes accepts Secret stringData and performs base64 conversion.
# The plaintext exists in process memory briefly but is not written to disk.
$plainApiKey = [System.Net.NetworkCredential]::new(
  "",
  $ApiKey
).Password

if ([string]::IsNullOrWhiteSpace($plainApiKey)) {
  Write-Error "API key must not be empty."
  exit 1
}

try {
  $secretManifest = @{
    apiVersion = "v1"
    kind = "Secret"
    metadata = @{
      name = $secretName
      namespace = $namespace
      labels = @{
        "app.kubernetes.io/name" = "kubewatch-backend"
        "app.kubernetes.io/part-of" = "kubewatch"
      }
    }
    type = "Opaque"
    stringData = @{
      KUBEWATCH_API_KEY = $plainApiKey
    }
  } | ConvertTo-Json -Depth 5 -Compress

  # Send the manifest through stdin so the plaintext is not placed
  # in the command line or stored in a tracked manifest file.
  $secretManifest | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  Write-Host "Local Secret applied: $namespace/$secretName"
}
finally {
  # Remove references as soon as the kubectl operation finishes.
  # Managed memory cannot guarantee immediate physical erasure.
  $plainApiKey = $null
  $secretManifest = $null
}
