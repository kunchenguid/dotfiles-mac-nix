#!/bin/bash

set -euo pipefail

DOTFILES_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && cd .. && pwd )

# Fail early if placeholder values have not been customized yet
if grep -R -n -E 'yourname|/Users/yourname|Your Name|you@example.com' \
  "$DOTFILES_DIR/flake.nix" \
  "$DOTFILES_DIR/nix" >/dev/null 2>&1; then
  echo "Placeholder values are still present in the repo."
  echo "Please replace values like 'yourname', '/Users/yourname', 'Your Name', and 'you@example.com' before running setup/mac.sh."
  exit 1
fi

# Install Nix — Determinate installer for Apple Silicon; pinned 2.24.x for Intel
# (Nix 2.25+ requires std::pmr from libc++, only available on macOS 13+)
if ! command -v nix &> /dev/null; then
  ARCH=$(uname -m)
  if [ "$ARCH" = "arm64" ]; then
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate
  else
    curl --proto '=https' --tlsv1.2 -sSf -L https://releases.nixos.org/nix/nix-2.24.10/install | sh -s -- --daemon
  fi
fi

# Install Homebrew if missing
if ! command -v brew &> /dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Enable experimental features globally so all nix subprocess calls pick them up
NIX_CONF=/etc/nix/nix.conf
if ! sudo grep -q 'nix-command' "$NIX_CONF" 2>/dev/null; then
  echo 'extra-experimental-features = nix-command flakes' | sudo tee -a "$NIX_CONF" > /dev/null
fi

# Apply the Nix configuration
if [ -x /run/current-system/sw/bin/darwin-rebuild ]; then
  /run/current-system/sw/bin/darwin-rebuild switch --flake "$DOTFILES_DIR#mac"
else
  # Build nix-darwin using our flake's pinned nixpkgs so nix-darwin's own
  # nixpkgs-unstable (which has coreutils-9.11 requiring macOS 13+) is never used.
  # Run darwin-rebuild as the current user (not root) so Homebrew activation works;
  # darwin-rebuild internally uses sudo only for the system-level parts.
  pushd "$DOTFILES_DIR" > /dev/null
  nix build --extra-experimental-features 'nix-command flakes' .#darwinConfigurations.mac.system
  ./result/sw/bin/darwin-rebuild switch --flake ".#mac"
  popd > /dev/null
fi

# Install nvm and a default Node.js if missing
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  PROFILE=/dev/null bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install --lts
fi

echo "Bootstrap complete. Restart your shell if needed, then use 'rebuild' or darwin-rebuild for future config changes."
