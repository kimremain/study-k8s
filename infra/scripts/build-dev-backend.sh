#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/../.." && pwd)"
backend_context="$project_root/backend"

project_id="study-gcp-cicd"
region="asia-northeast3"
repository="study-cicd-images"
image_name="kubewatch-backend"

for command_name in git gcloud; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

configured_project="$(gcloud config get-value project 2>/dev/null)"
if [[ "$configured_project" != "$project_id" ]]; then
  echo "Refusing to build for unexpected GCP project: $configured_project" >&2
  echo "Expected project: $project_id" >&2
  exit 1
fi

if [[ -n "$(git -C "$project_root" status --porcelain)" ]]; then
  echo "Refusing to build from a dirty Git worktree." >&2
  echo "Commit or discard local changes so the image tag identifies its source exactly." >&2
  exit 1
fi

commit="$(git -C "$project_root" rev-parse --short=12 HEAD)"
tag="${commit}-dev"
tagged_image="${region}-docker.pkg.dev/${project_id}/${repository}/${image_name}:${tag}"

echo "Building Backend image with Cloud Build"
echo "Source commit: $commit"
echo "Tagged image: $tagged_image"
gcloud builds submit "$backend_context" \
  --project="$project_id" \
  --region="$region" \
  --tag="$tagged_image"

digest="$(
  gcloud artifacts docker images describe "$tagged_image" \
    --project="$project_id" \
    --format='value(image_summary.digest)'
)"

if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "Artifact Registry returned an invalid digest: $digest" >&2
  exit 1
fi

immutable_image="${region}-docker.pkg.dev/${project_id}/${repository}/${image_name}@${digest}"
echo "Backend image push completed: $immutable_image"
