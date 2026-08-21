#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
fi

project_id="study-gcp-cicd"
region="asia-northeast3"
cluster="kubewatch-dev"
namespace="kubewatch-dev"
kubernetes_service_accounts=("kubewatch-backend" "kubewatch-collector")
google_service_account="kubewatch-backend-dev"
google_service_account_email="${google_service_account}@${project_id}.iam.gserviceaccount.com"
workload_pool="${project_id}.svc.id.goog"

for command_name in gcloud kubectl; do
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
if [[ "$current_context" != *kubewatch-dev* ]]; then
  echo "Refusing to configure from unexpected Kubernetes context: $current_context" >&2
  exit 1
fi

actual_workload_pool="$(
  gcloud container clusters describe "$cluster" \
    --project="$project_id" \
    --region="$region" \
    --format='value(workloadIdentityConfig.workloadPool)'
)"
if [[ "$actual_workload_pool" != "$workload_pool" ]]; then
  echo "Unexpected Workload Identity pool: $actual_workload_pool" >&2
  exit 1
fi

if ! gcloud iam service-accounts describe "$google_service_account_email" \
  --project="$project_id" >/dev/null 2>&1; then
  echo "Creating Google service account: $google_service_account_email"
  gcloud iam service-accounts create "$google_service_account" \
    --project="$project_id" \
    --display-name="KubeWatch dev Backend"
fi

echo "Granting the Google service account Cloud SQL Client access"
gcloud projects add-iam-policy-binding "$project_id" \
  --member="serviceAccount:${google_service_account_email}" \
  --role="roles/cloudsql.client" \
  --condition=None >/dev/null

for kubernetes_service_account in "${kubernetes_service_accounts[@]}"; do
  echo "Allowing $kubernetes_service_account to use the Google identity"
  gcloud iam service-accounts add-iam-policy-binding "$google_service_account_email" \
    --project="$project_id" \
    --member="serviceAccount:${workload_pool}[${namespace}/${kubernetes_service_account}]" \
    --role="roles/iam.workloadIdentityUser" >/dev/null
done

echo "Backend Workload Identity bootstrap completed: $google_service_account_email"
