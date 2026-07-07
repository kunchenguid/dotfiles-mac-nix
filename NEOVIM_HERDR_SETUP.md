# Neovim + Herdr Setup Notes

Record of how Neovim and [Herdr](https://herdr.dev/) config were added to this repo, and why, for future reference.

## Reference

Added by following [Kun Chen's "L8 Principal's Agentic Dev Environment From Scratch"](https://www.youtube.com/watch?v=5N-okeDdIuI) video. The Neovim and Herdr config themselves were pulled directly from his actual private dotfiles at [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles) (`home/.config/nvim` and `home/.config/herdr`) — this repo is a fork of his public template ([kunchenguid/dotfiles-mac-nix](https://github.com/kunchenguid/dotfiles-mac-nix)), whose `README.md` explicitly says editor config and AI tooling were left out of the public version on purpose.

## What Herdr is

A terminal-based agent multiplexer — like tmux, but for coding agents instead of shells. Each agent gets a real PTY pane, sessions persist over SSH/disconnect, and there's a built-in status view (blocked/working/done) across agents. Kun Chen runs Herdr panes for agents alongside a Neovim pane for quick file/diff/edit work, all keyboard-driven in one terminal.

- Site: https://herdr.dev/
- Source: https://github.com/ogulcancelik/herdr

## Files added

```
files/.config/nvim/
├── init.lua                  # requires vim_config, plugin, keys
├── lazy-lock.json            # pinned plugin commits (reproducibility)
└── lua/
    ├── vim_config.lua        # leader key, indenting, clipboard, undo, etc.
    ├── plugin.lua            # bootstraps lazy.nvim, loads lua/plugins/*
    ├── keys.lua              # Esc-to-save, select-all, paste-without-clobber
    └── plugins/
        ├── navigation.lua    # oil.nvim (file browser) + snacks.nvim (picker)
        ├── git.lua           # neogit + gitsigns.nvim
        └── ui.lua            # which-key.nvim

files/.config/herdr/
└── config.toml               # Ctrl+B prefix keybindings
```

These are plain config files, not managed by any Nix module directly — they get symlinked into place (see below).

## Nix wiring

**`flake.nix`**
- Added `herdr` as a flake input: `herdr.url = "github:ogulcancelik/herdr";`
  - Necessary because `herdr` isn't in the `nixpkgs-24.11-darwin` channel this repo pins (it's a newer package) — checked with `nix eval github:NixOS/nixpkgs/<pinned-rev>#herdr` and it doesn't resolve there, but `nix flake show github:ogulcancelik/herdr` confirms it ships its own `packages.x86_64-darwin.default`.
- Passed `herdr` into Home Manager via `home-manager.extraSpecialArgs = { inherit herdr; };` so `nix/user.nix` can use it.

**`nix/user.nix`**
- Module signature changed from `{ config, pkgs, ... }` to `{ config, pkgs, herdr, ... }` to receive the new input.
- Added `herdr.packages.${pkgs.system}.default` to `home.packages` (Neovim itself was already there).
- Added symlinks in `home.file`, following the same pattern already used for WezTerm:
  ```nix
  ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.config/nvim";
  ".config/herdr".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.config/herdr";
  ```
  `mkOutOfStoreSymlink` (rather than copying) means editing the files in `files/.config/nvim` or `files/.config/herdr` takes effect immediately — no `rebuild` needed for config-only changes, only for package/input changes.

**`flake.lock`**
- Updated via `nix flake lock --update-input herdr` to pin the new input's revision.

## Applying / verifying

```bash
rebuild   # zsh alias -> darwin-rebuild switch --flake .../dotfiles-mac-nix#mac
```

Validated before committing with:
```bash
nix flake check --no-build
nix build ".#darwinConfigurations.mac.system" --dry-run
```
Both passed — the herdr input resolves and the whole config evaluates/builds.

## Cheat sheet

**Neovim** (leader = space)
| Key | Action |
|---|---|
| `<leader>e` | Oil file browser |
| `<leader>f` | Find files (snacks picker) |
| `<leader>s` | Grep text |
| `<leader>b` | Buffers |
| `<leader>g` | Neogit |
| `gd` | Goto LSP definition |
| `<Esc>` (normal mode) | Save |
| `<C-a>` | Select all |

**Herdr** (prefix = `Ctrl+B`)
| Key | Action |
|---|---|
| `prefix h/j/k/l` | Focus pane left/down/up/right |
| `prefix "` | Split horizontal |
| `prefix %` | Split vertical |
| `prefix c` | New tab |
| `prefix &` | Close tab |
| `prefix w` | Workspace picker |
| `prefix g` | Goto |
| `prefix y` | Enter copy mode |
