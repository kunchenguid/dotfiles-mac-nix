# dotfiles-mac-nix

This repo is the public, reusable core of my Mac setup.

It is built with [Nix](https://nixos.org/), [`nix-darwin`](https://github.com/nix-darwin/nix-darwin), [Home Manager](https://github.com/nix-community/home-manager), and declarative [Homebrew](https://brew.sh/). The goal is to give macOS developers a reproducible base they can fork and adapt without inheriting someone else's entire private dotfiles repo.

If you want the longer explanation, see the [blog post](https://open.substack.com/pub/kunchenguid/p/how-i-built-a-reproducible-mac-setup?utm_campaign=post-expanded-share&utm_medium=web).

## What this repo does

It gives you a structured starting point for managing a Mac setup in code:

- bootstrap a fresh Mac with `setup/mac.sh`
- configure macOS defaults with `nix-darwin`
- manage user packages and shell behavior with Home Manager
- install GUI apps and macOS-native tools declaratively with Homebrew
- keep selected app config in the repo and link it into place

I include [WezTerm](https://wezfurlong.org/wezterm/) as the one concrete app-config example because it is real enough to demonstrate the pattern without dragging in the more personal parts of my workflow.

## Agentic engineering workflow

This repo also bootstraps the terminal-centric, multi-agent workflow described in ["L8 Principal's Agentic Engineering Workflow"](https://www.youtube.com/watch?v=iQyg-KypKAA):

- **Agent harnesses**: [Claude Code](https://claude.ai), [Codex CLI](https://github.com/openai/codex), [Pi](https://github.com/earendil-works/pi), and [OpenCode](https://github.com/sst/opencode)
- **Session management**: `tmux`, configured declaratively via `programs.tmux` in `nix/user.nix` (vi copy-mode, mouse support, session persistence via `tmux-resurrect`/`tmux-continuum`)
- **Parallel work**: [Treehouse](https://github.com/kunchenguid/treehouse) for disposable git worktrees per agent session, pulled in as a Nix flake input
- **Planning & review pipeline**: [Lavish](https://github.com/kunchenguid/lavish-axi) (interactive HTML planning artifacts) and [No Mistakes](https://github.com/kunchenguid/no-mistakes) (review/test/docs/PR pipeline)
- **Long-running agents**: [Good Night, Have Fun](https://github.com/kunchenguid/gnhf) for unattended agent loops against a stop condition
- **Agent-ergonomic tools**: the [AXI](https://github.com/kunchenguid/axi) family (`gh-axi`, `chrome-devtools-axi`) and the [Vercel `skills` CLI](https://github.com/vercel-labs/skills) for installing/managing agent skills
- **Voice input**: [OpenSuperWhisper](https://github.com/Starmel/OpenSuperWhisper), a local Whisper dictation app, installed as a Homebrew cask

`setup/mac.sh` installs the npm-distributed pieces (Codex, Pi, `skills`, `gnhf`, `no-mistakes`) and registers the AXI-family skills globally. Homebrew (`nix/host.nix`) handles OpenCode and OpenSuperWhisper. Treehouse is a proper Nix package via the flake input.

Not included: a multi-agent orchestrator like [First Mate](https://github.com/kunchenguid/firstmate) (it's meant to be cloned as its own project workspace, not installed system-wide) and personal memory files (`~/.claude/CLAUDE.md` and friends) — those preferences are yours to write, not something a starter repo should invent for you.

## What is intentionally not included

This repo does **not** try to mirror my entire machine.

I left out things that are too personal or too workflow-specific to make a good public starter repo, including:

- editor config (bring your own — mine lives in its own repo)
- custom shell systems
- personal scripts
- agent memory files and personal preferences
- secrets and tokens
- private automation

The goal is to provide a reusable foundation that you can make your own.

## Repo structure

- `setup/mac.sh` — bootstrap a fresh Mac, including agent harnesses and workflow CLIs
- `flake.nix` — top-level Nix wiring (nixpkgs, nix-darwin, home-manager, treehouse)
- `nix/host.nix` — machine-level macOS config (nix-darwin), Homebrew brews/casks
- `nix/user.nix` — user environment: packages, shell, git, tmux, fonts, dotfiles (Home Manager)
- `files/.config/wezterm/wezterm.lua` — example app config linked into place
- `blog.md` — local copy of the [blog post](https://open.substack.com/pub/kunchenguid/p/how-i-built-a-reproducible-mac-setup?utm_campaign=post-expanded-share&utm_medium=web)

## How to use it

### 1. Clone the repo

```bash
git clone git@github.com:kunchenguid/dotfiles-mac-nix.git ~/github/dotfiles-mac-nix
cd ~/github/dotfiles-mac-nix
```

### 2. Replace the placeholders

Update values like:

- `yourname`
- `/Users/yourname`
- `Your Name`
- `you@example.com`

If you are on an Intel Mac, change the system target in `flake.nix` from:

```nix
system = "aarch64-darwin";
```

to:

```nix
system = "x86_64-darwin";
```

### 3. Run the bootstrap script on a fresh Mac

This repo is primarily set up for Apple Silicon Macs. If you are on Intel, make the architecture change above before you run the bootstrap script.

```bash
bash setup/mac.sh
```

The script will:

- install [Determinate Nix Installer](https://determinate.systems/nix-installer/) if needed
- install [Homebrew](https://brew.sh/) if needed
- apply the `nix-darwin` + Home Manager config
- install [`nvm`](https://github.com/nvm-sh/nvm) and a default Node.js version if needed

## How I manage changes later

After the initial bootstrap, the usual workflow is:

1. edit the Nix config
2. run:

```bash
rebuild
```

This alias is included in the shell config and expands to the repo path used in this guide:

```bash
/run/current-system/sw/bin/darwin-rebuild switch --flake ~/github/dotfiles-mac-nix#mac
```

## Where to add new tools

My rough rule of thumb:

- use **Home Manager / Nix** for reproducible baseline CLI tools, fonts, shell utilities, and user environment packages
- use **Homebrew** for GUI apps and macOS-native tools that fit naturally there
- use **ecosystem-specific package managers** like `npm` when that is the right abstraction for the tool

A good setup does not force every tool through one package manager. It just makes the ownership of each layer clear.

## Why this setup looks like this

I wanted a setup that was:

- reproducible on a new Mac
- structured enough to maintain
- pragmatic about macOS
- publishable without oversharing the rest of my workflow

That is why this repo focuses on the reusable core.

## Related

- Long-form write-up: [blog post](https://open.substack.com/pub/kunchenguid/p/how-i-built-a-reproducible-mac-setup?utm_campaign=post-expanded-share&utm_medium=web)
- GitHub repo: <https://github.com/kunchenguid/dotfiles-mac-nix>
