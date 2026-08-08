{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    # everyday cli
    ripgrep
    fd
    fzf
    jq
    bat
    delta
    gh
    git-lfs
    httpie
    lazygit
    neovim
    p7zip
    mkcert
    netcat-gnu
    tree-sitter
    # the font everything renders in
    nerd-fonts.hack

    # build / languages (versions also via mise for node/python)
    cmake
    go
    powershell  # brew cask currently breaks brew bundle API fetch

    # data
    libpq
    pgcli

    # cloud / k8s
    awscli2
    azure-cli
    google-cloud-sdk
    cloudflared
    kubectl
    kubernetes-helm
    kustomize
    kubectx
    kind
    k3d
    opentofu

    # docs / diagrams
    certbot
    pandoc
    graphviz

    # LSP servers (declarative; nvim-lspconfig wires them up in lua/plugins/lsp.lua)
    gopls                       # go
    pyright                     # python
    nil                         # nix - edits this very flake
    lua-language-server         # nvim + wezterm config
    marksman                    # markdown
    typescript-language-server  # ts/js (needs node on PATH via mise)

    # formatters (consumed by conform.nvim)
    nixpkgs-fmt
    shfmt
    stylua
    ruff                        # python format + lint, single binary
    prettier                    # js/ts/json/yaml/md

    # linters (consumed by nvim-lint)
    golangci-lint
    shellcheck
    statix                      # nix linter

    # terminal-first dev productivity
    # shell history & navigation
    atuin                       # shell history with context (sync disabled below)
    ghq                         # clone/organize repos by host, jump with zoxide
    zsh-fzf-tab                 # fzf-powered zsh tab completion
    # listing & files
    eza                         # ls replacement (exa successor) with icons/git
    yazi                        # fast rust terminal file manager
    glow                        # markdown viewer
    # git
    difftastic                  # syntax-aware diff (AST-aware)
    git-absorb                  # automatic fixup commits for stacked branches
    gh-dash                     # TUI dashboard for GitHub PRs/issues via gh
    onefetch                    # repo summary on cd
    # containers / k8s
    k9s                         # kubernetes TUI
    lazydocker                  # docker TUI, pairs with colima
    stern                       # multi-pod log tailing
    dive                        # explore docker image layers
    # data / config
    yq-go                       # yaml processor (mikefarah/yq)
    dasel                       # jq/yq/toml/csv/xml in one tool
    visidata                    # spreadsheet TUI for csv/parquet/sql
    # dev tooling
    just                        # modern make, plain-text command runner
    hyperfine                   # statistical command benchmarking
    tealdeer                    # fast tldr cheatsheets
    sops                        # secrets management (pairs with 1password)
    age                         # modern encryption for sops
    # system monitoring
    bottom                      # rust htop replacement (btm)
    dust                        # du replacement, intuitive disk usage
    procs                       # ps replacement, colorful and filterable
  ];

  fonts.fontconfig.enable = true;
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    BAT_THEME = "TwoDark";
  };
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/go/bin"
    "$HOME/.opencode/bin"
    "$HOME/Library/pnpm"
  ];

  programs.mise = {
    enable = true;
    # globalConfig left empty so the edit-in-place symlink below owns config.toml
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide.enable = true;

  # Shell history with context. Sync disabled for security - shell history
  # commonly contains pasted tokens/secrets; keep it local-only.
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = false;
      sync_address = "";
      search_mode = "fuzzy";
      filter_mode = "global";
      style = "compact";
      inline_height = 30;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable = true;
    # Identity intentionally unset - set locally or add settings.user here.
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      fetch.prune = true;
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    # Login shells on macOS read .zprofile; keep brew/OrbStack but prefer Nix CLIs.
    profileExtra = ''
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
      [ -f "$HOME/.orbstack/shell/init.zsh" ] && . "$HOME/.orbstack/shell/init.zsh"
      export PATH="/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin:$HOME/.local/bin:$HOME/go/bin:$HOME/.opencode/bin:$PATH"
    '';
    initContent = ''
      bindkey '^f' autosuggest-accept

      # fzf-tab must load before other compinit hooks; source it early.
      if [ -f "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh" ]; then
        source "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh"
      fi

      # 1Password Dev-local secrets (CONTEXT7_API_KEY, AZURE_DEVOPS_EXT_PAT)
      if [ -r "$HOME/.config/zsh/dev-local-secrets.zsh" ]; then
        . "$HOME/.config/zsh/dev-local-secrets.zsh"
      fi

      # 1Password SSH agent - replaces macOS keychain for git/git-ssh auth.
      # Requires "Set up the SSH agent" enabled in 1Password > Settings > Developer.
      if [ -S "$HOME/.1password/agent.sock" ]; then
        export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
      fi

      # Friendlier defaults when tools are on PATH
      if (( $+commands[bat] )); then
        alias cat='bat --paging=never'
      fi
      if (( $+commands[eza] )); then
        alias ls='eza --group-directories-first'
        alias ll='eza -l --group-directories-first --git --icons'
        alias la='eza -la --group-directories-first --git --icons'
        alias lt='eza -l --tree --level=2 --git --icons'
      fi
      if (( $+commands[fd] )); then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      fi

      # Yandex Cloud CLI (optional local install)
      if [ -f "$HOME/yandex-cloud/path.bash.inc" ]; then
        . "$HOME/yandex-cloud/path.bash.inc"
      fi
      if [ -f "$HOME/yandex-cloud/completion.zsh.inc" ]; then
        . "$HOME/yandex-cloud/completion.zsh.inc"
      fi

      # Krew (if plugins were installed previously)
      export PATH="''${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
      cola = "colima start";
      colstop = "colima stop";
      cols = "colima status";
      v = "nvim";
      vi = "nvim";
      vim = "nvim";
      lg = "lazygit";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nodejs$python$dotnet$golang$kubernetes$docker_context$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
      nodejs = {
        format = "[$symbol($version )]($style)";
        symbol = "node ";
      };
      python = {
        format = "[$symbol($version )]($style)";
        symbol = "py ";
      };
      dotnet = {
        format = "[$symbol($version )]($style)";
        symbol = "net ";
      };
      golang = {
        format = "[$symbol($version )]($style)";
        symbol = "go ";
      };
      kubernetes = {
        format = "[$symbol$context ]($style)";
        symbol = "k8s ";
      };
      docker_context = {
        format = "[$symbol$context ]($style)";
        symbol = "docker ";
      };
    };
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".config/mise".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/mise";
  home.file.".config/zsh".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/zsh";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  # One global agent policy in the repo; every consumer is a symlink to it.
  home.file."AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
