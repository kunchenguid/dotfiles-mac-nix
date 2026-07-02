# Bootstrap

Run `setup/mac.sh` on a fresh Mac **after** cloning this repo and **after** replacing the placeholder values in the Nix files.

Typical flow:

1. Clone the repo
2. Replace placeholder values such as:
   - `yourname`
   - `/Users/yourname`
   - `Your Name`
   - `you@example.com`
3. Run:

```bash
bash setup/mac.sh
```

What the script does:

- checks that you replaced the placeholder values first
- installs Determinate Nix Installer if needed
- installs Homebrew if needed
- applies the `nix-darwin` + Home Manager configuration
- installs `nvm` and a default Node.js version if needed

This script is meant for the **first bootstrap on a new Mac**. After that, most ongoing changes should happen by editing the Nix config and running `darwin-rebuild switch --flake ~/github/dotfiles-mac-nix#mac`.

It's designed to complete in a single run: right after installing Nix it sources the daemon profile into the current shell, and the first `nix-darwin` activation resolves `nix` by absolute path with the experimental features it needs, so you should **not** need to run it twice or open a new shell partway through.

`NIX_DAEMON_PROFILE` and `DARWIN_REBUILD_BIN` are overridable only so the regression test can point the script at sandboxed paths.
For normal bootstrap usage, leave them unset.

## Testing

`setup/mac.sh` installs Nix and activates a real system, so tests never run it against the real machine. Instead:

```bash
bash tests/mac_setup_test.sh
```

This runs the actual script against a PATH-masked sandbox of stub executables that simulate a fresh Mac (and a second scenario for a machine that's already bootstrapped), without touching the network, the Nix store, Homebrew, sudo, or system state.
The harness also re-homes `NVM_DIR` under the sandboxed `HOME`, unsets inherited `BASH_ENV`/`ENV`, and refuses any harness or stub write path that escapes the temp sandbox.
See `AGENTS.md` for details.
