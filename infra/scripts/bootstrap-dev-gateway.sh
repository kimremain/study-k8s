#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
fi

project_id="study-gcp-cicd"
region="asia-northeast3"
cluster="kubewatch-dev"
gateway_class="gke-l7-global-external-managed"
expected_context="gke_${project_id}_${region}_${cluster}"

for command_name in gcloud jq kubectl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

configured_project="$(gcloud config get-value project 2>/dev/null)"
if [[ "$configured_project" != "$project_id" ]]; then
  echo "Refusing to configure an unexpected GCP project: $configured_project" >&2
  exit 1
fi

current_context="$(kubectl config current-context)"
if [[ "$current_context" != "$expected_context" ]]; then
  echo "Refusing to configure from unexpected Kubernetes context: $current_context" >&2
  exit 1
fi

cluster_description="$(
  gcloud container clusters describe "$cluster" \
    --project="$project_id" \
    --region="$region" \
    --format=json
)"

use_ip_aliases="$(jq -r '.ipAllocationPolicy.useIpAliases // false' <<<"$cluster_description")"
http_load_balancing_disabled="$(jq -r '.addonsConfig.httpLoadBalancing.disabled // false' <<<"$cluster_description")"
gateway_channel="$(jq -r '.networkConfig.gatewayApiConfig.channel // ""' <<<"$cluster_description")"

if [[ "$use_ip_aliases" != "true" ]]; then
  echo "Gateway API requires a VPC-native cluster" >&2
  exit 1
fi

if [[ "$http_load_balancing_disabled" == "true" ]]; then
  echo "Gateway API requires the HttpLoadBalancing add-on" >&2
  exit 1
fi

if [[ "$gateway_channel" != "CHANNEL_STANDARD" ]]; then
  echo "Enabling the Gateway API Standard channel"
  gcloud container clusters update "$cluster" \
    --project="$project_id" \
    --region="$region" \
    --gateway-api=standard \
    --quiet
fi

echo "Waiting for Gateway API resources"
for _ in $(seq 1 180); do
  if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 &&
    kubectl get "gatewayclass/$gateway_class" >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

if ! kubectl get "gatewayclass/$gateway_class" >/dev/null 2>&1; then
  echo "GatewayClass was not installed within 30 minutes: $gateway_class" >&2
  exit 1
fi

kubectl wait "gatewayclass/$gateway_class" \
  --for=condition=Accepted \
  --timeout=10m

echo "Gateway API bootstrap completed: $gateway_class"
