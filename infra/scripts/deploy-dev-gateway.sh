#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 || "$1" != "--confirm-public-load-balancer" ]]; then
  echo "Usage: $0 --confirm-public-load-balancer" >&2
  echo "This creates a public Google Cloud Application Load Balancer and incurs charges." >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
overlay="$project_root/infra/k8s/gateway/dev"
namespace="kubewatch-dev"
gateway="kubewatch-external"
route="kubewatch"
gateway_class="gke-l7-global-external-managed"
expected_context="gke_study-gcp-cicd_asia-northeast3_kubewatch-dev"

for command_name in curl jq kubectl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

current_context="$(kubectl config current-context)"
if [[ "$current_context" != "$expected_context" ]]; then
  echo "Refusing to deploy from unexpected Kubernetes context: $current_context" >&2
  exit 1
fi

if ! kubectl get "gatewayclass/$gateway_class" >/dev/null 2>&1; then
  echo "Required GatewayClass is missing; run bootstrap-dev-gateway.sh first" >&2
  exit 1
fi

for deployment in kubewatch-backend kubewatch-frontend; do
  kubectl wait "deployment/$deployment" \
    --namespace="$namespace" \
    --for=condition=Available \
    --timeout=5m
done

echo "Rendering dev Gateway resources"
rendered="$(kubectl kustomize "$overlay")"

echo "Running server-side dry run"
kubectl apply --dry-run=server -f - <<<"$rendered" >/dev/null

echo "Applying public dev Gateway resources"
kubectl apply -f - <<<"$rendered"

echo "Waiting for the external Application Load Balancer"
kubectl wait "gateway/$gateway" \
  --namespace="$namespace" \
  --for=condition=Programmed \
  --timeout=20m

route_ready=0
for _ in $(seq 1 120); do
  route_status="$(
    kubectl get "httproute/$route" \
      --namespace="$namespace" \
      --output=json
  )"
  accepted="$(
    jq -r '[.status.parents[]?.conditions[]? | select(.type == "Accepted" and .status == "True")] | length' \
      <<<"$route_status"
  )"
  resolved_refs="$(
    jq -r '[.status.parents[]?.conditions[]? | select(.type == "ResolvedRefs" and .status == "True")] | length' \
      <<<"$route_status"
  )"
  exact_backend_matches="$(
    jq -r '[
      .spec.rules[]?
      | select(any(.backendRefs[]?; .name == "kubewatch-backend"))
      | .matches[]?.path
      | select(.type == "Exact" and .value == "/api/v1/status")
    ] | length' <<<"$route_status"
  )"
  broad_backend_matches="$(
    jq -r '[
      .spec.rules[]?
      | select(any(.backendRefs[]?; .name == "kubewatch-backend"))
      | .matches[]?.path
      | select(.type != "Exact" or .value != "/api/v1/status")
    ] | length' <<<"$route_status"
  )"
  if ((
    accepted > 0 &&
      resolved_refs > 0 &&
      exact_backend_matches == 1 &&
      broad_backend_matches == 0
  )); then
    route_ready=1
    break
  fi
  sleep 5
done

if [[ "$route_ready" != "1" ]]; then
  echo "HTTPRoute was not accepted or Backend exposure was broader than /api/v1/status" >&2
  kubectl describe "httproute/$route" --namespace="$namespace" >&2
  exit 1
fi

address="$(
  kubectl get "gateway/$gateway" \
    --namespace="$namespace" \
    --output=jsonpath='{.status.addresses[0].value}'
)"
if [[ -z "$address" ]]; then
  echo "Gateway did not report an external address" >&2
  exit 1
fi

if [[ "$address" == *:* ]]; then
  public_origin="http://[$address]"
else
  public_origin="http://$address"
fi

echo "Waiting for public routes to become healthy: $public_origin"
frontend_ok=0
backend_ok=0
restricted_api_ok=0
for _ in $(seq 1 120); do
  if curl --fail --silent --max-time 10 "$public_origin/" \
    | grep -q '<div id="root">'; then
    frontend_ok=1
  fi
  if curl --fail --silent --max-time 10 "$public_origin/api/v1/status" \
    | grep -q '"status":"ok"'; then
    backend_ok=1
  fi
  if curl --fail --silent --max-time 10 "$public_origin/api/v1/resource-snapshots" \
    | grep -q '<div id="root">'; then
    restricted_api_ok=1
  fi
  if [[
    "$frontend_ok" == "1" &&
      "$backend_ok" == "1" &&
      "$restricted_api_ok" == "1"
  ]]; then
    break
  fi
  sleep 5
done

if [[
  "$frontend_ok" != "1" ||
    "$backend_ok" != "1" ||
    "$restricted_api_ok" != "1"
]]; then
  echo "Public route verification failed: frontend=$frontend_ok backend=$backend_ok restricted_api=$restricted_api_ok" >&2
  kubectl describe "gateway/$gateway" "httproute/$route" --namespace="$namespace" >&2
  exit 1
fi

kubectl get gateway,httproute,healthcheckpolicy --namespace="$namespace"
echo "Public Gateway deployment completed: $public_origin"
