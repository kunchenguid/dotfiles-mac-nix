# How I Built a Reproducible Mac Setup with Nix

Setting up a new Mac always sounds easier than it actually is.

You tell yourself it will take an hour. Install a few apps. Copy some dotfiles. Tweak a few settings. Done.

Then a full weekend disappears.

Some of your setup lives in shell config. Some is buried in macOS settings. Some is in packages you installed years ago and forgot about. Some is in app configs that only make sense after months of iteration. None of it feels hard while you are building it gradually. It only becomes painful when you have to do it again.

That was the problem I wanted to solve.

I wanted a reproducible core for my Mac setup.

A setup I could reapply on a new machine. A setup I could open source. A setup structured enough to be dependable, but not so rigid that it becomes annoying to maintain.

That led me to this stack:

- [Nix](https://nixos.org/)
- [`nix-darwin`](https://github.com/nix-darwin/nix-darwin)
- [Home Manager](https://github.com/nix-community/home-manager)
- declarative [Homebrew](https://brew.sh/)

The public version of that setup lives here:

- <https://github.com/kunchenguid/dotfiles-mac-nix>

This is the public, reusable core of my Mac setup. It is meant to be forked and adapted, not copied as a complete snapshot of someone else's machine.

In this post, I will walk through the ideas behind it and how I built each piece.

## What I wanted from this setup

I had three goals.

First, I wanted a setup that I could reproduce reliably on another Mac.

Second, I wanted a clean separation between machine-level concerns and user-level concerns.

Third, I wanted to stay pragmatic about macOS. That meant using Homebrew declaratively instead of pretending I should force everything through Nix just to be ideologically consistent.

## What Nix, nix-darwin, and Home Manager actually do

If you have never used this stack before, here is the short version.

### Nix

Nix is a package manager and configuration system.

The reason people like it is that it lets you describe an environment declaratively. Instead of manually installing packages and hoping you remember what you did six months later, you define the environment in code.

For me, the value is simple: I want my machine setup written down in a form I can version, reapply, and evolve.

### nix-darwin

`nix-darwin` brings that model to macOS.

It lets you configure machine-level parts of your Mac, including things like:

- system defaults
- login shell
- system packages
- Homebrew integration
- primary user configuration

So if Nix is the foundation, `nix-darwin` is the layer that makes it useful for a Mac.

### Home Manager

Home Manager does something similar, but for your user environment.

Instead of configuring the machine itself, it configures the things that live in your home directory and shape your day-to-day workflow:

- user packages
- Git config
- shell behavior
- fonts
- application config files
- environment variables

I like this split because it keeps system concerns and user concerns from getting mixed together.

### Declarative Homebrew

Even if you use Nix on macOS, [Homebrew](https://brew.sh/) is still useful.

A lot of Mac apps are easiest to install that way, especially GUI apps. So instead of pretending Homebrew should disappear, I let `nix-darwin` manage it declaratively.

That gives me a setup where both Nix packages and Homebrew apps live in source control.

## Step 1: Bootstrap the machine once

Before the declarative setup can take over, a fresh Mac still needs a small bootstrap step.

The reason is simple: on a brand new machine, the tools that apply the real configuration do not exist yet.

For this repo, the bootstrap layer lives in `setup/mac.sh`.

Its job is to install the minimum core tools needed to get the rest of the setup working:

- [Determinate Nix Installer](https://determinate.systems/nix-installer/) for installing [Nix](https://nixos.org/)
- [Homebrew](https://brew.sh/) for the macOS package/app layer managed by `nix-darwin`
- [`darwin-rebuild`](https://github.com/nix-darwin/nix-darwin) to apply the system configuration
- [nvm](https://github.com/nvm-sh/nvm) and Node.js for a practical JavaScript/TypeScript runtime baseline

On a fresh machine, the script also sources the Nix daemon profile immediately after the Determinate installer runs, so `nix` is available in the same shell.
If `darwin-rebuild` has never been activated, it uses the absolute `nix` path with flakes enabled to run the first `nix-darwin` activation in one pass.

Here is the bootstrap script:

```bash
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
```

I think this is an important pattern.

A fully declarative setup still usually needs a small bootstrap layer. On a brand new Mac, you need some way to install the tools that can then apply the real configuration.

So I think of the system in two phases:

1. **Bootstrap phase**: install the minimum needed to get going
2. **Declarative phase**: let Nix, `nix-darwin`, and Home Manager manage the durable setup

That bootstrap script is what you run on a **brand new Mac**, after cloning the repo and replacing the placeholder values with your own username, home directory, and Git identity.
The script checks for those placeholder values and fails early if you forgot.
It also handles the first Nix and `nix-darwin` activation without requiring a second shell or a second setup run.

In other words, the order is:

1. Clone the repo
2. Replace placeholders like `yourname`, `/Users/yourname`, and your Git identity
3. Run `bash setup/mac.sh`
4. Let the declarative setup take over from there

After that first bootstrap, ongoing changes should mostly be made by editing the Nix config and running `darwin-rebuild switch --flake ~/github/dotfiles-mac-nix#mac`.

I also like having a small convenience alias for this. In the public repo, I added an opinionated version that assumes the repo lives at `~/github/dotfiles-mac-nix`:

```nix
rebuild = "/run/current-system/sw/bin/darwin-rebuild switch --flake ~/github/dotfiles-mac-nix#mac";
```

That makes the common update loop a lot simpler: edit config, run `rebuild`, verify the result.

## Step 2: Create a flake as the entry point

The first thing I did was create a `flake.nix` file.

A flake is just the top-level definition of the setup. It declares the dependencies and how they are wired together.

In my case, I wanted three inputs:

- `nixpkgs` for packages
- `nix-darwin` for macOS system configuration
- `home-manager` for user configuration

The file looks like this:

```nix
{
  description = "Minimal macOS Nix setup with nix-darwin + Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix-darwin, home-manager, ... }: {
    darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./nix/host.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.yourname = import ./nix/user.nix;
        }
      ];
    };
  };
}
```

This is the file that turns the repo from a pile of config into a coherent system.

## Step 3: Define the machine-level setup with nix-darwin

Next I created `nix/host.nix`.

This file handles the machine-level parts of the setup: macOS defaults, Homebrew packages, the main user, the login shell, and system-level packages.

Here is the version from the public repo:

```nix
{ pkgs, ... }:

{
  # If you use Determinate Nix Installer (recommended), let it manage Nix itself.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    taps = [ ];
    brews = [
      "autoconf"
    ];
    casks = [
      "wezterm"
      "amethyst"
    ];
  };

  environment.systemPackages = with pkgs; [
    starship
  ];

  system.primaryUser = "yourname";
  users.users.yourname = {
    home = "/Users/yourname";
    shell = pkgs.zsh;
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      "com.apple.swipescrolldirection" = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      AppleShowAllExtensions = true;
    };

    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
    };

    trackpad = {
      Clicking = true;
    };
  };

  environment.systemPath = [
    "/run/current-system/sw/bin"
    "/etc/profiles/per-user/yourname/bin"
  ];

  system.stateVersion = 6;
}
```

This is where I put all the decisions that shape the machine itself.

For me, this is one of the highest-leverage parts of the setup. If I get a new Mac, I do not want to remember which settings I toggled manually in five different places. I want those decisions encoded once and re-applied.

## Step 4: Define the user environment with Home Manager

After that, I created `nix/user.nix`.

This is the user-level configuration. It includes packages, fonts, Git settings, prompt configuration, shell behavior, and dotfile symlinks.

```nix
{ config, pkgs, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/github/dotfiles-mac-nix";
in
{
  home.username = "yourname";
  home.homeDirectory = "/Users/yourname";
  home.stateVersion = "23.11";
  home.language.base = "en_US.UTF-8";

  home.packages = with pkgs; [
    git
    curl
    wget
    jq
    fd
    fastfetch
    ripgrep
    killall
    lazygit
    tree
    bun
    rustup
    zip
    unzip
    nerd-fonts.hack
    roboto
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    signing.format = null;
    settings = {
      user = {
        name = "Your Name";
        email = "you@example.com";
      };
      core.editor = "vim";
      color.ui = true;
      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.updateRefs = true;
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      command_timeout = 1000;
      add_newline = false;
      format = "$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$line_break$character";
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ".." = "cd ..";
      m = "git switch main";
      mst = "git switch master";
      pull = "git pull";
      push = "git push";
      pushf = "git push --force";
      add = "git add .";
      amend = "git commit --amend";
      reset = "git reset --soft HEAD^";
      rebasem = "git rebase -i main";
      rebasemst = "git rebase -i master";
      rebuild = "/run/current-system/sw/bin/darwin-rebuild switch --flake ~/github/dotfiles-mac-nix#mac";
    };
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
  };

  home.file = {
    ".config/wezterm".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.config/wezterm";
  };
}
```

The exact package list is not the important part. The structure is.

This is the layer where I define the baseline environment I want in my user account, including identity, packages, shell config, and dotfile symlinks all in one place.

## Step 5: Add one real app config as an example

I did not want this repo to be just Nix modules and placeholders, so I added one real application config: [WezTerm](https://wezfurlong.org/wezterm/).

The config lives in:

```text
files/.config/wezterm/wezterm.lua
```

And it gets linked into `~/.config/wezterm` through Home Manager.

The file itself is simple, but that is the point. It shows how to keep app config in the repo without turning the whole repo into a giant dump of personal preferences. I picked WezTerm because it is real enough to demonstrate the pattern while still being general enough for a public starter repo.

```lua
local wezterm = require("wezterm")

local config = wezterm.config_builder()

local is_windows = os.getenv("OS") and os.getenv("OS"):lower():find("windows")
local is_macos = wezterm.target_triple:lower():find("darwin") ~= nil

config.color_scheme = "rose-pine-moon"
config.max_fps = 120
config.font = wezterm.font("Hack Nerd Font", { weight = "DemiBold" })
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_frame = {
  font = wezterm.font("Hack Nerd Font", { weight = "Bold" }),
}
config.inactive_pane_hsb = {
  saturation = 0.0,
  brightness = 0.5,
}

if is_windows then
  config.win32_system_backdrop = "Acrylic"
  config.window_background_opacity = 0.7
  config.window_frame.font_size = 10.0
end

if is_macos then
  config.window_background_opacity = 0.8
  config.macos_window_background_blur = 50
  config.font_size = 15.0
  config.window_frame.font_size = 13.0
end

return config
```

## After Step 5: How I add more tools later

Once the base setup is in place, the next question is obvious: how do I install more stuff over time?

My rule of thumb is simple.

### Use Nix / Home Manager for things that should be part of the reproducible environment

That usually means:

- CLI tools I use regularly
- fonts
- shell utilities
- language toolchains that I want declared in the repo
- packages that belong in my default user environment

For example, adding another CLI package usually means editing `nix/user.nix` and adding it to `home.packages`, then running:

```bash
rebuild
```

### Use Homebrew for Mac apps that fit naturally there

For GUI apps and some macOS-native tools, Homebrew is often still the right place.

That means editing `nix/host.nix` and adding a formula to `brews` or an app to `casks`, then applying the config again.

### Use ecosystem-specific package managers when that is the right abstraction

Sometimes the right answer is not Nix or Homebrew.

For example:

- `npm` for global JavaScript tooling when that fits your workflow
- language-native package managers for project-specific dependencies

I do not think a good setup means forcing every possible tool through one package manager. I think it means being clear about which layer owns what.

My rough mental model is:

- **Nix / Home Manager** for reproducible baseline environment
- **Homebrew** for macOS apps and tools that fit naturally there
- **language-specific package managers** for ecosystem-specific or project-specific tooling

## What I intentionally left out

This repo does **not** include:

- my Neovim setup
- my custom shell environment
- my personal scripts
- AI tooling and agent config
- secrets or tokens
- private workflow automation

That is intentional.

The goal of this repo is not to mirror my entire machine. The goal is to provide a reusable core that other people can fork and adapt.

## The tradeoff

Whenever people talk about Nix, there is a tendency to turn every design choice into a purity test.

I do not think that is very useful on macOS.

The real questions are:

- Is the setup reproducible enough to trust?
- Is it understandable enough to maintain?
- Is it flexible enough to evolve?

That is why I am comfortable with a hybrid approach.

For stable parts of the environment, declarative config is great. For fast-moving app config, keeping files in the repo and linking them into place is often the easier choice.

I would rather have a setup that is practical and maintainable than one that is theoretically perfect and annoying to live with.

## How to use this repo

The repo is meant to be copied and adapted.

At a high level:

1. Clone the repo under your home directory
2. Replace the placeholders for username, home directory, and Git identity
3. If you are on Intel, change the system target from `aarch64-darwin` to `x86_64-darwin`
4. On a fresh Mac, run `bash setup/mac.sh`
5. For later changes, edit the Nix config and run `darwin-rebuild switch --flake ~/github/dotfiles-mac-nix#mac`

The goal is not to clone my machine exactly.

The goal is to start from a setup that already has a good structure.

## Why I open-sourced this version

My private dotfiles repo is larger and much more opinionated than what I wanted to publish.

This version is the part I think is generally useful.

It captures the structure, the layering, and the tradeoffs, without asking someone else to inherit all of my workflow decisions.

## Final thought

The point of a reproducible setup is not to freeze your environment forever.

It is to make your environment legible.

Once your setup has a clear structure, you stop relying on memory and habit to rebuild it. You can evolve it deliberately. You can move it to a new machine. You can share it without oversharing.

That is the real payoff: a setup you can understand, repeat, and keep.
