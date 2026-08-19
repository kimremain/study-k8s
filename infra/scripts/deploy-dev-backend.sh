#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
overlay="$project_root/infra/k8s/overlays/dev"
namespace="kubewatch-dev"
deployment="kubewatch-backend"
migration_job="kubewatch-backend-migration"
current_context="$(kubectl config current-context)"

if [[ "$current_context" != *kubewatch-dev* ]]; then
  echo "Refusing to deploy from unexpected Kubernetes context: $current_context" >&2
  exit 1
fi

if ! kubectl get secret kubewatch-database-secret \
  --namespace="$namespace" >/dev/null 2>&1; then
  echo "Required Secret is missing: $namespace/kubewatch-database-secret" >&2
  exit 1
fi

echo "Kubernetes context: $current_context"
echo "Rendering dev Backend resources"
rendered="$(kubectl kustomize "$overlay")"
expected_image="$(
  awk '
    $1 == "---" { deployment = 0 }
    $1 == "kind:" { kind = $2 }
    kind == "Deployment" && $1 == "name:" && $2 == "kubewatch-backend" {
      deployment = 1
    }
    deployment && $1 == "image:" { print $2; exit }
  ' <<<"$rendered"
)"

if [[ ! "$expected_image" =~ ^[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]]; then
  echo "Rendered Backend image is not an immutable digest: $expected_image" >&2
  exit 1
fi

echo "Running client-side dry run"
kubectl apply --dry-run=client -f - <<<"$rendered" >/dev/null

# A Job Pod template is immutable. Recreate this release-scoped migration Job
# so every deployment runs the migration from the declared Backend image.
kubectl delete job "$migration_job" \
  --namespace="$namespace" \
  --ignore-not-found \
  --wait=true

echo "Applying dev Backend resources"
kubectl apply -f - <<<"$rendered"

kubectl wait "job/$migration_job" \
  --namespace="$namespace" \
  --for=condition=complete \
  --timeout=10m

kubectl rollout status "deployment/$deployment" \
  --namespace="$namespace" \
  --timeout=10m

actual_image="$(
  kubectl get "deployment/$deployment" \
    --namespace="$namespace" \
    --output=jsonpath='{.spec.template.spec.containers[?(@.name=="backend")].image}'
)"

if [[ "$actual_image" != "$expected_image" ]]; then
  echo "Unexpected Backend image: $actual_image" >&2
  exit 1
fi

kubectl get job,deployment,pod,service,endpointslice --namespace="$namespace"
echo "Backend deployment completed: $expected_image"
