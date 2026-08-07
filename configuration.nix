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
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
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
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];

    # Survival list for this machine: tools used across Projects that are not
    # already provided by home.nix (ripgrep/fd/fzf/jq/lazygit/neovim).
    # Leaf libraries brew pulls in transitively are intentionally omitted.
    brews = [
      # agents / terminal
      "herdr"

      # shell / cli
      "bat"
      "gh"
      "git-delta"
      "git-lfs"
      "httpie"
      "mkcert"
      "p7zip"
      "zoxide"

      # runtimes / build
      "cmake"
      "dotnet"
      "go"
      "nvm"
      "pipx"

      # containers
      "colima"
      "docker"
      "docker-buildx"
      "docker-compose"
      "docker-credential-helper"

      # data
      "libpq"
      "pgcli"

      # cloud
      "awscli"
      "azure-cli"
      "cloudflared"

      # kubernetes
      "helm"
      "k3d"
      "kind"
      "krew"
      "kubernetes-cli"
      "kubectx"
      "kustomize"
      "opentofu"
    ];
    casks = [
      "claude-code"
      "dotnet-sdk"
      "espanso"
      "gcloud-cli"
      "maccy"
      "multipass"
      "ollama-app"
      "powershell"
      "temurin"
      "wezterm@nightly"
    ];
  };
}
