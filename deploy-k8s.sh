#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE="${FF_K8S_IMAGE:-ghcr.io/bigreds/feed-fiddler:latest}"
NAMESPACE="${FF_K8S_NAMESPACE:-feed-fiddler}"

# --- build & push image ---
echo "Building and pushing $IMAGE..."
docker buildx build --platform linux/amd64,linux/arm64 -t "$IMAGE" --push "$REPO"

# --- apply manifests ---
echo "Applying kustomize manifests..."
kubectl apply -k "$REPO/deploy/k8s"

# --- trigger a run now, rather than waiting for the schedule ---
JOB_NAME="feed-fiddler-manual-$(date +%s)"
echo "Triggering a run ($JOB_NAME)..."
kubectl create job "$JOB_NAME" --from=cronjob/feed-fiddler -n "$NAMESPACE"
