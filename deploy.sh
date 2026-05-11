#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- venv ---
VENV="$REPO/venv"
if [ ! -x "$VENV/bin/python" ]; then
    echo "Creating virtualenv..."
    python3 -m venv "$VENV"
fi
echo "Installing Python dependencies..."
"$VENV/bin/python" -m pip install -q -r "$REPO/requirements.txt"

# --- web UI ---
echo "Generating web UI..."
"$VENV/bin/python" "$REPO/web/generate.py"

# --- terraform ---
cd "$REPO/deploy"

TF="${TF_CMD:-}"
if [ -z "$TF" ]; then
    if command -v tofu &>/dev/null; then
        TF=tofu
    elif command -v terraform &>/dev/null; then
        TF=terraform
    else
        echo "Error: neither tofu nor terraform found on PATH" >&2
        exit 1
    fi
fi

# init is needed when providers change (e.g. first run after null provider was added)
if ! grep -q 'hashicorp/null' "$REPO/deploy/.terraform.lock.hcl" 2>/dev/null; then
    echo "Running $TF init (new provider detected)..."
    "$TF" init
fi

echo "Running $TF apply..."
"$TF" apply "$@"

DIST_ID=$("$TF" output -raw web_cloudfront_distribution_id 2>/dev/null || true)
if [ -n "$DIST_ID" ]; then
    echo "Invalidating CloudFront cache..."
    aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" --output text
fi
