{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;

  # /etc/pam.d is SIP-protected on this macOS; managing sudo_local fails activation.
  security.pam.services.sudo_local.enable = false;

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      # Keep the menu bar visible on normal Spaces/displays. WezTerm native
      # fullscreen still hides it on its own Space; true would hide it everywhere.
      _HIHideMenuBar = false;
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = true;
    inherit user;
    # Adopt the existing /opt/homebrew install; keeps bottles, replaces Homebrew itself.
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    # autoUpdate off: Homebrew's cask API currently breaks `powershell` fetch mid-bundle.
    onActivation.autoUpdate = false;
    onActivation.extraFlags = [ "--force" ];

    # Minimal brew: darwin gaps + agent multiplexer. Everyday CLIs live in home.nix.
    brews = [
      "herdr"
      "pi-coding-agent"
      "colima"
      "docker"
      "docker-buildx"
      "docker-compose"
      "docker-credential-helper"
    ];
    casks = [
      "claude-code"
      "dotnet-sdk"
      "espanso"
      "maccy"
      "multipass"
      "ollama-app"
      "temurin"
      "wezterm@nightly"
    ];
  };
}
