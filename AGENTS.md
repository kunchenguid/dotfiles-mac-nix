# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## setup/mac.sh: never run it for real

`setup/mac.sh` installs Nix (via the Determinate installer) and runs a real `nix-darwin` system activation (`darwin-rebuild switch` / `sudo nix run ... switch`). Never execute it, the real Determinate installer, `darwin-rebuild switch`, `sudo nix run ...`, the Homebrew installer, or the nvm installer against a dev machine or CI host - these mutate the host permanently. All validation of this script must go through `tests/mac_setup_test.sh`, which runs the actual script with PATH masked to stub executables so nothing real is ever installed or activated.

## Fresh-machine single-pass contract

`setup/mac.sh` must bootstrap a brand-new Mac in one run, with no "run it again in a new shell" step. After the Determinate installer runs, the script sources the Nix daemon profile (`NIX_DAEMON_PROFILE`, defaults to `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`) into the current shell so `nix` is usable immediately, then activates nix-darwin for the first time via `sudo <absolute nix path> --extra-experimental-features "nix-command flakes" run nix-darwin/master#darwin-rebuild -- switch --flake ...` (absolute path because `sudo` doesn't inherit the newly-sourced PATH). `NIX_DAEMON_PROFILE` and `DARWIN_REBUILD_BIN` are both overridable via environment variables (defaulting to the real canonical paths) specifically so tests can point them at a sandbox instead of the real filesystem. Any future edit to this bootstrap logic must preserve: single-pass success on a fresh machine, and the existing already-installed fast path (`$DARWIN_REBUILD_BIN switch`) staying untouched.

## Testing setup/mac.sh

Run `bash tests/mac_setup_test.sh`. It simulates a fresh Mac by copying the repo into a scratch fixture (placeholders pre-replaced), building stub `curl`/`sh`/`nix`/`darwin-rebuild`/`sudo`/`bash` executables that record invocations and fake just enough side effects (a profile script, a `nix` binary) for the script to progress, then running the real `setup/mac.sh` against that PATH-masked sandbox. It covers both the fresh-machine path (single-pass activation) and the already-installed fast path. It never touches the real network, Nix store, Homebrew, sudo, or system state. Set `DEBUG_KEEP_SANDBOX=1` to keep the scratch sandbox around for inspection after a failing run.

Each scenario sandboxes `HOME`, re-homes `NVM_DIR` under that temp root, and unsets inherited `BASH_ENV`/`ENV` before invoking `setup/mac.sh` (an inherited absolute `NVM_DIR` from hm-session-vars would otherwise leak stub writes).
Harness and stub writes call `assert_path_under_sandbox` / `guard_write_path` so a future leak through parent traversal, symlink escape, or another absolute write path fails the test instead of mutating the host.
