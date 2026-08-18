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
deployment="kubewatch-frontend"
current_context="$(kubectl config current-context)"

if [[ "$current_context" != *kubewatch-dev* ]]; then
  echo "Refusing to deploy from unexpected Kubernetes context: $current_context" >&2
  exit 1
fi

echo "Kubernetes context: $current_context"
echo "Rendering dev Frontend resources"
expected_image="$(
  kubectl kustomize "$overlay" |
    awk '
      image == "" {
        for (field = 1; field <= NF; field++) {
          if ($field == "image:") {
            image = $(field + 1)
          }
        }
      }
      END { print image }
    '
)"

if [[ ! "$expected_image" =~ ^[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]]; then
  echo "Rendered Frontend image is not an immutable digest: $expected_image" >&2
  exit 1
fi

echo "Running client-side dry run"
kubectl apply --dry-run=client -k "$overlay" >/dev/null

echo "Applying dev Frontend resources"
kubectl apply -k "$overlay"

kubectl rollout status "deployment/$deployment" \
  --namespace="$namespace" \
  --timeout=5m

actual_image="$(
  kubectl get "deployment/$deployment" \
    --namespace="$namespace" \
    --output=jsonpath='{.spec.template.spec.containers[0].image}'
)"

if [[ "$actual_image" != "$expected_image" ]]; then
  echo "Unexpected Frontend image: $actual_image" >&2
  exit 1
fi

kubectl get deployment,pod,service,endpointslice --namespace="$namespace"
echo "Frontend deployment completed: $expected_image"
