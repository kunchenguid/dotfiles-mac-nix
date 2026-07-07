{ config, pkgs, herdr, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/Desktop/Latest-Desktop/Reproducible Mac/dotfiles-mac-nix";
in
{
  home.username = "yash_khandelwal";
  home.homeDirectory = "/Users/yash_khandelwal";
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
    tmux
    uv
    python3
    docker-client
    docker-compose
    neovim
    herdr.packages.${pkgs.system}.default
    (nerdfonts.override { fonts = [ "Hack" ]; })
    roboto
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    UV_PYTHON_PREFERENCE = "managed";
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    userName = "YashWonder3";
    userEmail = "yash.khandelwal943@gmail.com";
    extraConfig = {
      core.editor = "nvim";
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
      format = "$username$hostname$directory$git_branch$git_state$git_status$nodejs$python$cmd_duration$line_break$character";

      directory.style = "blue";

      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](green)";
      };

      git_branch = {
        format = "[$branch]($style)";
        style = "bright-black";
      };

      git_status = {
        format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)";
        style = "cyan";
        stashed = "≡";
      };

      git_state = {
        format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
        style = "bright-black";
      };

      cmd_duration = {
        format = "[$duration]($style) ";
        style = "yellow";
      };

      python = {
        format = "[🐍$version($virtualenv)]($style) ";
        style = "bright-black";
      };
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
      rebuild = "/run/current-system/sw/bin/darwin-rebuild switch --flake ~/Desktop/Latest-Desktop/Reproducible\\ Mac/dotfiles-mac-nix#mac";
      dstart = "colima start";
      dstop = "colima stop";
      dstatus = "colima status";
      vim = "nvim";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };
    envExtra = ''
      # Prefer Temurin 21 (managed via dotfiles); fall back to any Java 21 on the machine
      if [[ -d "/Library/Java/JavaVirtualMachines/temurin-21.jdk" ]]; then
        export JAVA_HOME="/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home"
      else
        export JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null)
      fi
    '';
    initExtra = ''
      bindkey '^f' autosuggest-accept

      # Ensure Nix profile paths are always first, even when tmux inherits a stale environment
      path=("/etc/profiles/per-user/${config.home.username}/bin" "$HOME/.nix-profile/bin" $path)

      # Add Java to PATH (JAVA_HOME is set in ~/.zshenv via envExtra, available here)
      [ -n "$JAVA_HOME" ] && path=("$JAVA_HOME/bin" $path)

      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

      # goenv — per-project Go version management via .go-version files
      export GOENV_ROOT="$HOME/.goenv"
      export GOPATH="$HOME/go"
      [ -d "$GOENV_ROOT/bin" ] && path=("$GOENV_ROOT/bin" $path)
      command -v goenv &>/dev/null && eval "$(goenv init -)"
      path=("$GOPATH/bin" $path)

      # Auto-activate uv venv when entering a project directory
      function _uv_venv_activate() {
        if [[ -f "$PWD/.venv/bin/activate" ]]; then
          source "$PWD/.venv/bin/activate"
        elif [[ -n "$VIRTUAL_ENV" && "$PWD" != "$VIRTUAL_ENV"* ]]; then
          deactivate
        fi
      }
      autoload -U add-zsh-hook
      add-zsh-hook chpwd _uv_venv_activate
      _uv_venv_activate  # run on shell start in case already inside a project
    '';
  };

  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    historyLimit = 10000;
    keyMode = "vi";
    prefix = "C-a";
    mouse = true;
    escapeTime = 0;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      resurrect
      {
        plugin = continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
      yank
    ];

    extraConfig = ''
      # Start panes as login shells so Nix profile PATH is always loaded
      set -g default-command "${pkgs.zsh}/bin/zsh -l"

      # Split with | and - keeping current path
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # New window keeps current path
      bind c new-window -c "#{pane_current_path}"

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

      # Status bar
      set -g status-position top
      set -g status-style "bg=default,fg=white"
      set -g status-left "#[fg=blue,bold]#S #[fg=white,nobold]| "
      set -g status-right "#[fg=yellow]%H:%M #[fg=white]| #[fg=cyan]#h"
      set -g status-left-length 30
      set -g window-status-current-style "fg=magenta,bold"

      # Resize panes with vim keys (hold prefix)
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # True color support
      set -as terminal-overrides ",xterm-256color:RGB"
    '';
  };

  home.file = {
    ".config/wezterm".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.config/wezterm";
    ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.config/nvim";
    ".config/herdr".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.config/herdr";
  };
}
