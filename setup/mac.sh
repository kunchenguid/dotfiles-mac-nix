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

# Install Nix via Determinate if missing
if ! command -v nix &> /dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
fi

# Install Homebrew if missing
if ! command -v brew &> /dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apply the Nix configuration
if [ -x /run/current-system/sw/bin/darwin-rebuild ]; then
  sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$DOTFILES_DIR#mac"
else
  sudo nix run github:nix-darwin/nix-darwin -- switch --flake "$DOTFILES_DIR#mac"
fi

# Install Claude Code if missing
if ! command -v claude &> /dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Install other agent harnesses if missing
if ! command -v codex &> /dev/null; then
  npm install -g @openai/codex
fi

if ! command -v pi &> /dev/null; then
  npm install -g @earendil-works/pi-coding-agent
fi

# Vercel's skills CLI for installing/managing agent skills across harnesses
if ! command -v skills &> /dev/null; then
  npm install -g skills
fi

# Kun Chen's open-source agent-ergonomics tooling (github.com/kunchenguid)
if ! command -v gnhf &> /dev/null; then
  npm install -g gnhf
fi

if ! command -v no-mistakes &> /dev/null; then
  curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
fi

# Register the AXI-family tools as globally available agent skills
if command -v skills &> /dev/null; then
  skills add kunchenguid/lavish-axi --skill lavish -g
  skills add kunchenguid/axi -g
  skills add kunchenguid/gh-axi --skill gh-axi -g
  skills add kunchenguid/chrome-devtools-axi --skill chrome-devtools-axi -g
  skills add anthropics/skills --skill skill-creator -g
fi

# Install nvm and a default Node.js if missing
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  PROFILE=/dev/null bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install --lts
fi

echo "Bootstrap complete. Restart your shell if needed, then use 'rebuild' or darwin-rebuild for future config changes."
