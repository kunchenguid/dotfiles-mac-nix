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

  # The installer wires Nix into new shells, but this script is still running
  # in the shell that started before Nix existed. Source the daemon profile
  # now so `nix` works for the rest of this run instead of needing a second
  # session. The profile script isn't written to be `set -u` safe, so relax
  # that guard just around the source. (Overridable so tests can point at a
  # sandboxed profile instead of the real one.)
  : "${NIX_DAEMON_PROFILE:=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh}"
  if [ -f "$NIX_DAEMON_PROFILE" ]; then
    set +u
    # shellcheck disable=SC1090
    . "$NIX_DAEMON_PROFILE"
    set -u
  fi
fi

# Install Homebrew if missing
if ! command -v brew &> /dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apply the Nix configuration. (DARWIN_REBUILD_BIN is overridable so tests
# can point at a sandboxed binary instead of the real one.)
: "${DARWIN_REBUILD_BIN:=/run/current-system/sw/bin/darwin-rebuild}"
if [ -x "$DARWIN_REBUILD_BIN" ]; then
  sudo "$DARWIN_REBUILD_BIN" switch --flake "$DOTFILES_DIR#mac"
else
  # First activation: nix-darwin has never run, so darwin-rebuild doesn't
  # exist yet and has to be fetched via `nix run`. Resolve nix by absolute
  # path since sudo won't inherit the PATH this script just sourced, and
  # enable the experimental features it needs in case nix.conf doesn't
  # already have them.
  NIX_BIN=$(command -v nix || echo /nix/var/nix/profiles/default/bin/nix)
  sudo "$NIX_BIN" --extra-experimental-features "nix-command flakes" \
    run nix-darwin/master#darwin-rebuild -- switch --flake "$DOTFILES_DIR#mac"
fi

# Install nvm and a default Node.js if missing
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  PROFILE=/dev/null bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install --lts
fi

echo "Bootstrap complete. Restart your shell if needed, then use 'rebuild' or darwin-rebuild for future config changes."
