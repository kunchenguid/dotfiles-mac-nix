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
  ];

  system.stateVersion = 6;
}
