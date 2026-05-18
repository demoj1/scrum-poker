#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$ROOT_DIR"

if ! command -v mix >/dev/null 2>&1; then
  echo "mix is required to run this project locally" >&2
  exit 1
fi

if ! command -v yarn >/dev/null 2>&1; then
  echo "yarn is required to run this project locally" >&2
  exit 1
fi

mix local.hex --force
mix local.rebar --force
mix deps.get

yarn --cwd assets install --frozen-lockfile
yarn --cwd assets deploy

exec mix phx.server
