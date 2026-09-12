#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE="${FF_K8S_IMAGE:-ghcr.io/bigreds/feed-fiddler:latest}"

# Builds and pushes the image locally — github does this on every v* tag via
# .github/workflows/build-image.yaml so this is only for manual local testing
echo "Building and pushing $IMAGE..."
docker buildx build --platform linux/amd64,linux/arm64 -t "$IMAGE" --push "$REPO"
