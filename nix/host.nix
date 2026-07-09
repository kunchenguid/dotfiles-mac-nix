{ pkgs, ... }:

{
  # If you use Determinate Nix Installer (recommended), let it manage Nix itself.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;
    onActivation.cleanup = "none";
    taps = [ ];
    brews = [
      "autoconf"
      # OpenCode: model-agnostic coding agent CLI/TUI (homebrew-core formula)
      "opencode"
    ];
    casks = [
      "wezterm"
      "amethyst"
      # Free/open-source local Whisper dictation app used for voice-driven
      # agent prompting (Starmel/OpenSuperWhisper)
      "opensuperwhisper"
      # Antigravity CLI (agy): Google's terminal agent harness, successor to
      # Gemini CLI, used to reach Antigravity's models/quota via Google AI
      # Pro from the terminal. Homebrew cask rather than nixpkgs since it
      # ships new releases fast and a pinned flake.lock nixpkgs revision
      # would otherwise lag behind (same reasoning as OpenCode below).
      "antigravity-cli"
    ];
  };

  environment.systemPackages = with pkgs; [
    starship
    tmux
  ];

  system.primaryUser = "yuweiyan";
  users.users.yuweiyan = {
    home = "/Users/yuweiyan";
    shell = pkgs.zsh;
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      "com.apple.swipescrolldirection" = true;
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
      Clicking = false;
    };
  };

  environment.systemPath = [
    "/run/current-system/sw/bin"
    "/etc/profiles/per-user/yuweiyan/bin"
    # Homebrew formulae (e.g. opencode, autoconf) live here; Homebrew's own
    # installer only offers to add this via a shell-profile eval, which would
    # get clobbered by Home Manager's declarative dotfiles anyway.
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  system.stateVersion = 6;
}
