# Dev Environment Setup

Portable, reproducible developer setup for macOS (Monterey 12.7.6+, Intel x86_64) built on Nix + nix-darwin + Home Manager. Clone the repo, run one script, get the same environment on any Mac.

## Stack

| Layer | Tool | Managed by |
|---|---|---|
| Package manager | Nix + Home Manager | `nix/user.nix` |
| System config | nix-darwin | `nix/host.nix` |
| GUI apps | Homebrew casks | `nix/host.nix` |
| Terminal emulator | WezTerm | `files/.config/wezterm/wezterm.lua` |
| Terminal multiplexer | tmux | `programs.tmux` in `nix/user.nix` |
| Shell | zsh + starship | `programs.zsh` in `nix/user.nix` |
| Node.js | nvm | sourced in `initExtra` |
| Python | python3 (Nix) + uv | `home.packages` + `initExtra` |
| Docker | Colima + docker-client | `nix/host.nix` + `nix/user.nix` |
| Java | Eclipse Temurin 21 LTS | `homebrew.casks` in `nix/host.nix` + `envExtra` in `nix/user.nix` |
| Editor | Neovim 0.10.2 | `home.packages` in `nix/user.nix` |
| Go | goenv (multi-version) | `homebrew.brews` in `nix/host.nix` + `initExtra` |

---

## Bootstrap a New Mac

```bash
git clone git@github.com:YashWonder3/dotfiles-mac-nix.git ~/Desktop/Latest-Desktop/Reproducible\ Mac/dotfiles-mac-nix
cd ~/Desktop/Latest-Desktop/Reproducible\ Mac/dotfiles-mac-nix
bash setup/mac.sh
```

The script installs Nix, Homebrew, applies the nix-darwin config, and sets up nvm.

After first bootstrap, all future changes are applied with:

```bash
rebuild
```

---

## WezTerm

Config lives at `files/.config/wezterm/wezterm.lua` and is symlinked into place by Home Manager.

- Font: Hack Nerd Font DemiBold, 15pt
- Color scheme: rose-pine-moon
- Background opacity: 0.8 with blur (macOS)
- Max FPS: 120
- Integrated window buttons

To edit: open `files/.config/wezterm/wezterm.lua` and run `rebuild`.

---

## tmux

Managed entirely by Home Manager (`programs.tmux`). Config is generated at `~/.config/tmux/tmux.conf` — do not edit it directly.

**Prefix:** `Ctrl-a`

### Key bindings

| Key | Action |
|---|---|
| `prefix + \|` | Horizontal split (keeps current path) |
| `prefix + -` | Vertical split (keeps current path) |
| `prefix + c` | New window (keeps current path) |
| `prefix + r` | Reload tmux config |
| `prefix + H/J/K/L` | Resize pane (left/down/up/right) |
| `Ctrl + h/j/k/l` | Navigate panes (or nvim splits via vim-tmux-navigator) |
| `y` (copy mode) | Yank to system clipboard |
| `prefix + Ctrl-s` | Save session (resurrect) |
| `prefix + Ctrl-r` | Restore session (resurrect) |

### Plugins (Nix-managed, no TPM)

| Plugin | Purpose |
|---|---|
| sensible | Sane defaults |
| vim-tmux-navigator | Unified pane/split navigation with nvim |
| resurrect | Manual session save/restore |
| continuum | Auto-save session every 15 min, restore on start |
| yank | System clipboard integration in copy mode |

### Status bar

- Position: top
- Left: session name
- Right: time + hostname
- Active window: magenta bold

---

## Shell (zsh + starship)

### Prompt format

```
directory git_branch git_status node_version python_version duration
❯
```

Python version shows as `🐍3.12.x(venv-name)` only in directories with Python project files or an active venv.

### Aliases

| Alias | Command |
|---|---|
| `rebuild` | Apply nix-darwin config changes |
| `..` | `cd ..` |
| `add` | `git add .` |
| `push` / `pull` | `git push` / `git pull` |
| `pushf` | `git push --force` |
| `amend` | `git commit --amend` |
| `reset` | `git reset --soft HEAD^` |
| `m` / `mst` | Switch to main / master |
| `rebasem` / `rebasemst` | Interactive rebase onto main / master |
| `dstart` | `colima start` |
| `dstop` | `colima stop` |
| `dstatus` | `colima status` |
| `vim` | `nvim` |

### Key bindings

| Key | Action |
|---|---|
| `Ctrl + f` | Accept autosuggestion |

---

## Node.js (nvm)

nvm is sourced in every shell (WezTerm and tmux) via `initExtra`.

```bash
nvm install --lts        # install latest LTS
nvm use 20               # switch version
nvm alias default 20     # set default
node --version
```

The default nvm version loads automatically in every new shell.

---

## Python

Two layers:

- **`python3` (Nix)** — global baseline, Python 3.12, always in PATH
- **`uv`** — per-project version management, venv creation, package installation

### Per-project workflow

```bash
# One-time: install the Python versions you need
uv python install 3.12
uv python install 3.13

# Per project
cd my-project
echo "3.13" > .python-version   # pin version for this project
uv venv                          # creates .venv with Python 3.13
uv pip install requests pandas   # install packages into venv
```

The venv **auto-activates** when you `cd` into the project directory — in both WezTerm and tmux — via the `_uv_venv_activate` zsh hook in `initExtra`. No manual `source .venv/bin/activate` needed.

When you `cd` out of the project, the venv auto-deactivates.

### Version consistency across terminals

Both WezTerm and tmux panes always use the same Python because:
1. Nix profile PATH is explicitly prepended in every shell via `initExtra`
2. The auto-venv hook fires on every `cd` in every shell

---

## Docker (Colima + docker-client)

Docker Desktop is not used. Instead:

- **Colima** (Homebrew) — lightweight Linux VM that runs the Docker daemon (~600MB RAM)
- **docker-client** (Nix) — Docker CLI, always in PATH in both terminals
- **docker-compose** (Nix) — Compose V2, works as `docker compose` and `docker-compose`

### Workflow

```bash
dstart                          # start Colima VM + Docker daemon
docker ps                       # verify daemon is running
docker run hello-world          # test

docker-compose up -d            # start services (Compose V2)
docker compose up -d            # same, plugin syntax

dstatus                         # check Colima status
dstop                           # stop Colima when done
```

### First-time setup after rebuild

Colima is installed via Homebrew but not started automatically. Run `dstart` once after each machine reboot before using Docker. To auto-start at login:

```bash
brew services start colima
```

### Compatibility

| Component | Version | macOS Monterey |
|---|---|---|
| Colima | 0.10.3 | ✓ |
| docker-client | 27.5.1 | ✓ |
| docker-compose | 2.30.3 | ✓ |

---

## Java (Eclipse Temurin 21 LTS)

Managed via Homebrew cask (`temurin@21`). Installs to the standard macOS JVM location so `/usr/libexec/java_home` and IDEs find it automatically.

### How JAVA_HOME is set

`JAVA_HOME` is exported in `envExtra` (→ `~/.zshenv`), which is sourced for **all** shell types — interactive, non-interactive, login, and scripts. This is what makes Java consistent across WezTerm and tmux:

```zsh
# ~/.zshenv (generated by envExtra in user.nix)
if [[ -d "/Library/Java/JavaVirtualMachines/temurin-21.jdk" ]]; then
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home"
else
  export JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null)
fi
```

Temurin is matched by path first — not by `java_home` selection — so it is always preferred over any other Java 21 installation (e.g. Oracle JDK) that may exist on the machine.

`$JAVA_HOME/bin` is then prepended to PATH in `initExtra` (→ `~/.zshrc`):

```zsh
[ -n "$JAVA_HOME" ] && path=("$JAVA_HOME/bin" $path)
```

### Verify

```bash
java -version         # Eclipse Temurin 21 LTS
echo $JAVA_HOME       # /Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
javac -version        # javac 21.x.x
```

### Why Temurin over Oracle JDK

| | Oracle JDK 21 | Eclipse Temurin 21 |
|---|---|---|
| License | Oracle NFTC (restricted commercial use) | GPL v2 + Classpath Exception (fully open) |
| Managed by | Manual installer | Homebrew cask — declarative |
| TCK certified | Yes | Yes |
| Compatibility | Java 21 LTS | Java 21 LTS (identical) |

Both pass the Java TCK — for development they are interchangeable.

---

## Go (goenv)

Multiple Go versions managed via `goenv` (Homebrew), with per-project version pinning via `.go-version` files — the same pattern as Python's `.python-version`.

### Per-project workflow

```bash
# One-time: install the Go versions you need
goenv install 1.23.0
goenv install 1.22.6

# Set a global default
goenv global 1.23.0

# Per project
cd my-project
echo "1.22.6" > .go-version    # goenv auto-switches when you cd in
go version                      # → go1.22.6
```

goenv auto-switches the active Go version whenever you `cd` into a directory with a `.go-version` file — in both WezTerm and tmux, because init runs in every interactive shell via `initExtra`.

### PATH layout

| Path | Purpose |
|---|---|
| `~/.goenv/bin` | goenv binary |
| `~/.goenv/shims` | shims for `go`, `gofmt`, etc. (added by `goenv init -`) |
| `~/go/bin` | `GOPATH/bin` — installed Go tools (`go install ...`) |

### Verify

```bash
goenv versions        # list installed versions
go version            # active version in current directory
echo $GOPATH          # ~/go
which go              # ~/.goenv/shims/go
```

### Consistency across WezTerm and tmux

`goenv init -` runs in `initExtra` (→ `~/.zshrc`) on every interactive shell start. Both WezTerm windows and tmux panes source `~/.zshrc`, so the same Go version is active in both based on the `.go-version` file in your current directory.

---

## Neovim

Installed via Nix (`neovim` 0.10.2) — always in PATH in both WezTerm and tmux via the Nix profile.

```bash
nvim file.txt     # open file
vim file.txt      # alias → nvim
```

### What's pre-wired for compatibility

| Feature | How |
|---|---|
| True color | tmux sets `terminal-overrides` for `xterm-256color:RGB`; WezTerm passes through 24-bit color |
| `TERM` | tmux sets `tmux-256color`; Neovim detects true color automatically |
| Pane navigation | tmux `vim-tmux-navigator` plugin installed — add the matching Neovim plugin to use `Ctrl+h/j/k/l` across panes and splits |
| Default editor | `EDITOR=nvim` set in `home.sessionVariables` — used by git commit, `fc`, etc. |
| Git commit editor | `core.editor = nvim` in `programs.git` |

### vim-tmux-navigator Neovim plugin

The tmux side is already configured. To complete the integration, add this to your Neovim plugin manager:

```lua
-- lazy.nvim
{ "christoomey/vim-tmux-navigator" }
```

Once installed, `Ctrl+h/j/k/l` navigates seamlessly between Neovim splits and tmux panes in both WezTerm and tmux.

### Config location

Neovim config is intentionally not managed by this repo (too personal). Place yours at `~/.config/nvim/`. It will persist across rebuilds since Home Manager does not touch that path.

---

## PATH and env consistency (WezTerm vs tmux)

Two layers ensure every tool version is identical across WezTerm windows and tmux panes:

### Layer 1 — `envExtra` → `~/.zshenv` (all shell types)

Used for environment variables that must be available everywhere, including non-interactive scripts. Currently sets `JAVA_HOME`:

```zsh
# Sourced for every shell zsh starts — no guard variable blocks it
if [[ -d "/Library/Java/JavaVirtualMachines/temurin-21.jdk" ]]; then
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home"
else
  export JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null)
fi
```

### Layer 2 — `initExtra` → `~/.zshrc` (interactive shells)

Used for PATH manipulation and tool initialisation. Runs in every WezTerm window and every tmux pane (which start as `zsh -l`, a login + interactive shell):

```zsh
# Nix profile always first — prevents tmux from using a stale PATH when
# __NIX_DARWIN_SET_ENVIRONMENT_DONE is inherited and blocks /etc/zshenv re-run
path=("/etc/profiles/per-user/yash_khandelwal/bin" "$HOME/.nix-profile/bin" $path)

# Java — JAVA_HOME already exported from ~/.zshenv above
[ -n "$JAVA_HOME" ] && path=("$JAVA_HOME/bin" $path)

# Node — nvm sourced here so the default version loads in every pane
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

### Result

| Tool | Consistent via |
|---|---|
| git, python3, docker, uv | Nix profile prepended in `initExtra` |
| java / javac | `JAVA_HOME` in `envExtra` + PATH in `initExtra` |
| node | nvm sourced in `initExtra` |
| Python venv | auto-activate hook in `initExtra` (fires on every `cd`) |

---

## Adding new tools

| Tool type | Where to add |
|---|---|
| CLI tools, fonts, language runtimes | `home.packages` in `nix/user.nix` |
| GUI apps | `homebrew.casks` in `nix/host.nix` |
| macOS-native daemons/formulas | `homebrew.brews` in `nix/host.nix` |
| Shell aliases | `shellAliases` in `programs.zsh` |
| Env vars needed everywhere (incl. scripts) | `envExtra` in `programs.zsh` → `~/.zshenv` |
| PATH manipulation, tool init, hooks | `initExtra` in `programs.zsh` → `~/.zshrc` |

After any change, run `rebuild` to apply.
