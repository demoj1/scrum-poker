#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="scrum-poker-local"
CONTAINER_NAME="scrum-poker-local"

cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not installed locally. Use ./run-local.sh or run this script on a machine with Docker." >&2
  exit 1
fi

docker build -t "$IMAGE_NAME" .

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

exec docker run --rm -p 4005:4005 --name "$CONTAINER_NAME" "$IMAGE_NAME"
