{ config, pkgs, treehouse, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/repos/github/dotfiles-mac-nix";
in
{
  home.username = "yuweiyan";
  home.homeDirectory = "/Users/yuweiyan";
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
    uv
    nodejs_22
    gh
    htop
    btop
    rclone
    cmake
    neovim
    awscli2
    zip
    unzip
    # Git worktree manager for running parallel agent sessions without
    # them stepping on each other (github.com/kunchenguid/treehouse)
    treehouse.packages.${pkgs.system}.default
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
    JAVA_HOME = "/Library/Java/JavaVirtualMachines/jdk-23.jdk/Contents/Home";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.cargo/bin"
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
    signing.format = null;
    settings = {
      user = {
        name = "Yuwei Yan";
        email = "yuweiyan@uchicago.edu";
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
        format = "[$virtualenv]($style) ";
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
      rebuild = "/run/current-system/sw/bin/darwin-rebuild switch --flake ~/github/dotfiles-mac-nix#mac";
    };
    initContent = ''
      bindkey '^f' autosuggest-accept

      # >>> conda initialize >>>
      # !! Contents within this block are managed by 'conda init' !!
      __conda_setup="$('/Users/yuweiyan/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
      if [ $? -eq 0 ]; then
          eval "$__conda_setup"
      else
          if [ -f "/Users/yuweiyan/miniconda3/etc/profile.d/conda.sh" ]; then
              . "/Users/yuweiyan/miniconda3/etc/profile.d/conda.sh"
          else
              export PATH="/Users/yuweiyan/miniconda3/bin:$PATH"
          fi
      fi
      unset __conda_setup
      # <<< conda initialize <<<

      # Ensure nix-managed tools (e.g. uv, node) take priority over conda's,
      # since conda init above prepends its own bin dir to PATH.
      export PATH="/etc/profiles/per-user/yuweiyan/bin:$HOME/.nix-profile/bin:/run/current-system/sw/bin:$PATH"
    '';
  };

  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];
    extraConfig = ''
      set -g renumber-windows on
      set -ga terminal-overrides ",*256col*:Tc"

      # Split panes in the current path with | and -, keep default % and " too
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Vim-style pane navigation, repeatable
      bind -r h select-pane -L
      bind -r j select-pane -D
      bind -r k select-pane -U
      bind -r l select-pane -R

      # Status bar
      set -g status-position top
      set -g status-style "bg=default,fg=#908caa"
      set -g status-left "#[fg=#c4a7e7,bold] #S "
      set -g status-right "#[fg=#908caa] %Y-%m-%d %H:%M "
      setw -g window-status-current-format "#[fg=#e0def4,bold] #I:#W "
      setw -g window-status-format "#[fg=#6e6a86] #I:#W "
    '';
  };

  home.file = {
    ".config/wezterm".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/files/.config/wezterm";
  };
}
