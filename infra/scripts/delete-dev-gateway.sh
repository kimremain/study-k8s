#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 || "$1" != "--confirm-delete-public-load-balancer" ]]; then
  echo "Usage: $0 --confirm-delete-public-load-balancer" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
overlay="$project_root/infra/k8s/gateway/dev"
namespace="kubewatch-dev"
gateway="kubewatch-external"
expected_context="gke_study-gcp-cicd_asia-northeast3_kubewatch-dev"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Required command not found: kubectl" >&2
  exit 1
fi

current_context="$(kubectl config current-context)"
if [[ "$current_context" != "$expected_context" ]]; then
  echo "Refusing to delete from unexpected Kubernetes context: $current_context" >&2
  exit 1
fi

kubectl delete -k "$overlay" --ignore-not-found

if kubectl get "gateway/$gateway" --namespace="$namespace" >/dev/null 2>&1; then
  echo "Gateway deletion is still reconciling: $namespace/$gateway"
else
  echo "Gateway resources deleted; Google Cloud load balancer cleanup can take several minutes"
fi
