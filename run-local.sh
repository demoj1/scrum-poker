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

mix local.hex --force >/dev/null
mix local.rebar --force >/dev/null
mix deps.get >/dev/null

if ! yarn --cwd assets install --frozen-lockfile --silent >/dev/null 2>&1; then
  yarn --cwd assets install --frozen-lockfile
  exit 1
fi

if ! yarn --cwd assets deploy >/dev/null 2>&1; then
  yarn --cwd assets deploy
  exit 1
fi

if ! mix compile >/dev/null 2>&1; then
  mix compile
  exit 1
fi

export POKER_DISABLE_RELOAD=1

filter_known_noise() {
  perl -ne '
    our $skip ||= 0;

    if (/^warning: Phoenix\.(?:LiveView|HTML)\.Engine\.handle_text\/2 is deprecated/ ||
        /^warning: using map\.field notation \(without parentheses\)/) {
      $skip = 1;
      next;
    }

    if ($skip) {
      if (/^\s*$/) {
        $skip = 0;
      }
      next;
    }

    print;
  '
}

mix phx.server 2>&1 | filter_known_noise
