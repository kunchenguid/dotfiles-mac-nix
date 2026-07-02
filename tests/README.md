# Tests

Run all tests with:

```bash
bash tests/mac_setup_test.sh
```

`mac_setup_test.sh` is a regression test for `setup/mac.sh`.
It never runs the script against the real machine, since that script installs Nix and activates a real `nix-darwin` system.
Instead it runs the actual `setup/mac.sh` against a PATH-masked sandbox of stub executables (`curl`, `sh`, `nix`, `darwin-rebuild`, `sudo`, `bash`) that simulate a fresh Mac.
The stubs also make sure the bootstrap uses the canonical `install.determinate.systems` installer URL.

It covers two scenarios:

- a fresh machine, where the script must install Nix, source the daemon profile into the current shell, and activate `nix-darwin` for the first time, all in a single pass with no second-session step
- an already-bootstrapped machine, where the existing `darwin-rebuild switch` fast path is used instead

See `AGENTS.md` for the fresh-machine single-pass contract these tests protect.
