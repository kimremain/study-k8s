#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <artifact-registry-image@sha256:digest>" >&2
  exit 2
fi

image_ref="$1"
if [[ ! "$image_ref" =~ ^[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]]; then
  echo "Image must be an immutable digest reference: <image>@sha256:<64 hex>" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
runtime_overlay="$project_root/tmp/kustomize-frontend-dev"
runtime_kustomization="$runtime_overlay/kustomization.yaml"
namespace="kubewatch-dev"
deployment="kubewatch-frontend"
image_name="${image_ref%@*}"
image_digest="${image_ref#*@}"
current_context="$(kubectl config current-context)"

if [[ "$current_context" != *kubewatch-dev* ]]; then
  echo "Refusing to deploy from unexpected Kubernetes context: $current_context" >&2
  exit 1
fi

mkdir -p "$runtime_overlay"

cat > "$runtime_kustomization" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../infra/k8s/overlays/dev
images:
  - name: kubewatch-frontend
    newName: ${image_name}
    digest: ${image_digest}
EOF

echo "Kubernetes context: $current_context"
echo "Rendering dev Frontend resources"
kubectl kustomize "$runtime_overlay" >/dev/null

echo "Running client-side dry run"
kubectl apply --dry-run=client -k "$runtime_overlay" >/dev/null

echo "Applying dev Frontend resources"
kubectl apply -k "$runtime_overlay"

kubectl rollout status "deployment/$deployment" \
  --namespace="$namespace" \
  --timeout=5m

actual_image="$(
  kubectl get "deployment/$deployment" \
    --namespace="$namespace" \
    --output=jsonpath='{.spec.template.spec.containers[0].image}'
)"

if [[ "$actual_image" != "$image_ref" ]]; then
  echo "Unexpected Frontend image: $actual_image" >&2
  exit 1
fi

kubectl get deployment,pod,service,endpointslice --namespace="$namespace"
echo "Frontend deployment completed: $actual_image"
