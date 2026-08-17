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
    # WezTerm fonts (loaded via ~/Library/Fonts/HomeManager in wezterm.lua).
    # Cycle with Alt+Shift+F / Alt+Shift+B; default is FiraMono Nerd Font.
    nerd-fonts.fira-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-cove         # Cascadia Code
    nerd-fonts.geist-mono
    nerd-fonts.commit-mono
    nerd-fonts.monaspace              # Neon/Argon/Xenon/Radon/Krypton
    nerd-fonts.iosevka-term
    nerd-fonts.blex-mono              # IBM Plex Mono
    nerd-fonts.intone-mono            # Intel One Mono
    nerd-fonts.victor-mono
    nerd-fonts.zed-mono
    nerd-fonts.martian-mono
    nerd-fonts.sauce-code-pro         # Source Code Pro

    # build / languages (versions also via mise for node/python)
    cmake
    go
    powershell  # brew cask currently breaks brew bundle API fetch

    # data
    libpq
    pgcli
    duckdb                     # in-process OLAP; query CSV/Parquet/JSON/SQLite via SQL
    usql                       # universal SQL CLI (postgres/mysql/sqlite/sqlserver/duckdb)
    miller                     # jq for CSV/TSV/tabular data

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
    taplo                       # toml LSP + formatter (mise/direnv/starship config)
    yaml-language-server        # yaml LSP (k8s/CI configs)

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
    actionlint                  # lint GitHub Actions workflows
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
    gitleaks                    # secret scanner; run as a pre-commit hook
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
      # Transparently route HTTPS git URLs through SSH (and thus 1Password's SSH
      # agent) for the common hosts. Azure DevOps is excluded because its SSH
      # URL format rearranges the path (_git/ -> v3/); use `git2ssh` for that.
      url."git@github.com:".insteadOf = "https://github.com/";
      url."git@gitlab.com:".insteadOf = "https://gitlab.com/";
      url."git@bitbucket.org:".insteadOf = "https://bitbucket.org/";
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
      # The symlink ~/.1password/agent.sock is created by home-manager (see home.nix).
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

      # git2ssh - rewrite the current repo's origin from HTTPS to SSH.
      # Handles GitHub/GitLab/Bitbucket (simple host swap) and Azure DevOps
      # (dev.azure.com and *.visualstudio.com -> ssh.dev.azure.com:v3, _git/ -> v3/).
      # The insteadOf git config already rewrites the common hosts transparently,
      # so this is mainly for Azure DevOps or when you want the stored remote to be SSH.
      git2ssh() {
        local url new
        url=$(git remote get-url origin 2>/dev/null) || { echo "no origin remote"; return 1; }
        case "$url" in
          git@*) echo "already SSH: $url"; return 0 ;;
          https://github.com/*)     new="git@github.com:''${url#https://github.com/}" ;;
          https://gitlab.com/*)    new="git@gitlab.com:''${url#https://gitlab.com/}" ;;
          https://bitbucket.org/*) new="git@bitbucket.org:''${url#https://bitbucket.org/}" ;;
          https://dev.azure.com/*/_git/*|https://*.visualstudio.com/*/_git/*)
            local rest="''${url#https://*/}"      # org/project/_git/repo
            local repo="''${rest##*/_git/}"
            local orgproj="''${rest%/_git/$repo}"
            new="git@ssh.dev.azure.com:v3/$orgproj/$repo" ;;
          *) echo "unrecognized URL: $url"; return 1 ;;
        esac
        git remote set-url origin "$new" && echo "$url -> $new"
      }
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
      # Modules: dir (truncated) -> git -> language runtimes (auto-detected per
      # project) -> direnv (only with .envrc).
      # docker_context, cmd_duration, and kubernetes intentionally dropped -
      # docker was noise (always-on when Colima is the active context), duration
      # added clutter, and k8s context is rare in the regular flow.
      format = "$directory$git_branch$git_status$nodejs$python$dotnet$golang$direnv$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
        truncate_to_repo = true;
      };
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
      direnv = {
        disabled = false;
        format = "[$symbol$loaded/$allowed]($style) ";
        symbol = "direnv ";
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
  home.file.".local/bin/sanitize-paste".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.local/bin/sanitize-paste";
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

  # 1Password SSH agent lives in its sandboxed Group Container; expose it at a
  # stable, machine-agnostic path so SSH_AUTH_SOCK in zsh init can point at it.
  # The socket only exists while 1Password is running; a dangling symlink is fine.
  home.file.".1password/agent.sock".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

  # Kimi Code CLI is a self-contained Node SEA binary its installer drops at
  # ~/.kimi-code/bin/kimi (alongside a bundled rg). Expose only `kimi` on PATH
  # via ~/.local/bin (already in sessionPath) so it doesn't shadow the nix rg.
  home.file.".local/bin/kimi".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.kimi-code/bin/kimi";
}
