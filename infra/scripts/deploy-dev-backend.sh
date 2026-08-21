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
collector_cronjob="kubewatch-resource-collector"
collector_service_account="system:serviceaccount:${namespace}:kubewatch-collector"
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
expected_collector_image="$(
  awk '
    $1 == "---" { cronjob = 0 }
    $1 == "kind:" { kind = $2 }
    kind == "CronJob" && $1 == "name:" && $2 == "kubewatch-resource-collector" {
      cronjob = 1
    }
    cronjob && $1 == "image:" && $2 ~ /kubewatch-backend/ { print $2; exit }
  ' <<<"$rendered"
)"

if [[ ! "$expected_image" =~ ^[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]]; then
  echo "Rendered Backend image is not an immutable digest: $expected_image" >&2
  exit 1
fi

if [[ "$expected_collector_image" != "$expected_image" ]]; then
  echo "Collector and Backend images differ: $expected_collector_image" >&2
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

actual_collector_image="$(
  kubectl get "cronjob/$collector_cronjob" \
    --namespace="$namespace" \
    --output=jsonpath='{.spec.jobTemplate.spec.template.spec.containers[?(@.name=="collector")].image}'
)"
if [[ "$actual_collector_image" != "$expected_image" ]]; then
  echo "Unexpected collector image: $actual_collector_image" >&2
  exit 1
fi

if [[ "$(
  kubectl auth can-i list pods \
    --namespace="$namespace" \
    --as="$collector_service_account"
)" != "yes" ]] || [[ "$(
  kubectl auth can-i list deployments.apps \
    --namespace="$namespace" \
    --as="$collector_service_account"
)" != "yes" ]]; then
  echo "Collector ServiceAccount cannot list its required resources." >&2
  exit 1
fi

if [[ "$(
  kubectl auth can-i list secrets \
    --namespace="$namespace" \
    --as="$collector_service_account" 2>/dev/null || true
)" != "no" ]]; then
  echo "Collector ServiceAccount unexpectedly has permission to list Secrets." >&2
  exit 1
fi

verification_job="${collector_cronjob}-check-$(date +%s)"
echo "Running one immediate collector Job: $verification_job"
kubectl create job "$verification_job" \
  --namespace="$namespace" \
  --from="cronjob/$collector_cronjob"
if ! kubectl wait "job/$verification_job" \
  --namespace="$namespace" \
  --for=condition=complete \
  --timeout=5m; then
  kubectl logs "job/$verification_job" \
    --namespace="$namespace" \
    --all-containers=true \
    --prefix=true || true
  exit 1
fi
kubectl logs "job/$verification_job" \
  --namespace="$namespace" \
  --container=collector

kubectl get cronjob,job,deployment,pod,service,endpointslice --namespace="$namespace"
echo "Backend deployment completed: $expected_image"
echo "Resource collector deployment completed: cronjob/$collector_cronjob"
