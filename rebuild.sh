#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# sudo resets PATH; resolve tools before elevating (same pattern as bootstrap.sh).
NIX_BIN="$(command -v nix)"
if command -v darwin-rebuild >/dev/null 2>&1; then
  DARWIN_REBUILD="$(command -v darwin-rebuild)"
  exec sudo "$DARWIN_REBUILD" switch --flake ~/.dotfiles#mac
fi

exec sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#mac
