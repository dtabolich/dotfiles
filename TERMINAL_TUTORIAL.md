# Terminal first-user tour

A 5-minute walkthrough of what's installed and the keys/commands that matter.
Everything here comes from `home.nix` and the symlinked configs under `home/`.

## Shell

- `zsh` with autosuggestions, syntax highlighting, and fzf-powered tab completion.
- Prompt is `starship` - it shows dir, git branch/status, node/python/go/.net/k8s/docker context, and last command duration.
- `Ctrl+F` accepts an autosuggestion. Tab opens an fzf menu for any completion.
- Aliases (from `home.nix`):

  | Alias                       | Does                                                                               |
  | --------------------------- | ---------------------------------------------------------------------------------- |
  | `ll` / `la` / `lt`          | `eza` long / all / tree listing with icons + git status                            |
  | `cat`                       | `bat` (syntax-highlighted, no paging)                                              |
  | `v` / `vi` / `vim`          | `nvim`                                                                             |
  | `lg`                        | `lazygit` TUI                                                                      |
  | `m`                         | `git switch main`                                                                  |
  | `add` / `push` / `pull`     | git shortcuts                                                                      |
  | `cola` / `colstop` / `cols` | colima start/stop/status                                                           |
  | `cc` / `co`                 | `claude --dangerously-skip-permissions` / `codex --full-auto` (know what these do) |

## Navigation and history

- `z <query>` (zoxide) jumps to a frequently/ recently used directory by fuzzy match.
- `atuin` owns history. `Ctrl+R` opens an inline fuzzy search across full history with the directory you ran the command from.
- `ghq get <repo>` clones into `~/ghq/github.com/owner/repo`; jump back with `z <repo>`.

## Files and viewing

- `yazi` - terminal file manager (`yazi` to launch, `q` to quit).
- `eza` replaces `ls`; `bat` replaces `cat` (alias above).
- `glow <file.md>` renders markdown in the terminal.
- `tree` is not aliased - use `lt` for a 2-level eza tree, or `eza -l --tree --level=N`.

## Git

- `lazygit` (`lg`) - full TUI for staging/committing/branching.
- `git diff` / `git log` are piped through `delta` for syntax-aware diffs.
- `difftastic` (`difft a.txt b.txt`) - AST-aware diff.
- `git absorb` - auto-creates fixup commits for stacked branches.
- `gh-dash` (`gh dash`) - TUI dashboard for your PRs and issues.
- `onefetch` - run inside a repo for a one-screen summary.

## Editor (Neovim)

First launch bootstraps `lazy.nvim` from GitHub - needs network once, then offline.

Leader is `\` (default). The keys that matter:

| Key          | Action                     |
| ------------ | -------------------------- |
| `<leader>f`  | Find files (Snacks picker) |
| `<leader>s`  | Grep across project        |
| `<leader>b`  | Switch buffers             |
| `<leader>e`  | Open oil.nvim file browser |
| `gd`         | Go to definition           |
| `gr`         | References                 |
| `gi`         | Implementation             |
| `gD`         | Declaration                |
| `K`          | Hover docs                 |
| `<leader>ca` | Code action                |
| `<leader>rn` | Rename symbol              |
| `<leader>d`  | Line diagnostics           |
| `[d` / `]d`  | Prev / next diagnostic     |

LSP servers (`gopls`, `pyright`, `nil_ls`, `lua_ls`, `marksman`, `ts_ls`), formatters (`nixpkgs-fmt`, `shfmt`, `stylua`, `ruff`, `prettier`, `gofmt`), and linters (`golangci-lint`, `shellcheck`, `statix`, `ruff`) are all installed via Nix - format-on-save is on, linting runs on save and buffer enter.

## Containers and k8s

- `lazydocker` - Docker TUI (pairs with `colima`).
- `k9s` - Kubernetes TUI. `kubectx` / `kubens` switch context/namespace.
- `stern <pod-prefix>` - tail logs across multiple pods.
- `dive <image>` - explore image layers.
- `kind` / `k3d` - local clusters.

## Data and config

- `jq` (JSON), `yq` (YAML), `dasel` (any of jq/yq/toml/csv/xml in one tool).
- `visidata <file>` - spreadsheet TUI for CSV / Parquet / SQL.
- `pgcli` - Postgres REPL with autocomplete.

## System and dev

- `btm` (bottom) - `htop` replacement. `dust` - disk usage. `procs` - `ps` replacement.
- `hyperfine 'cmd A' 'cmd B'` - benchmark commands statistically.
- `tldr <cmd>` - fast cheatsheet (e.g. `tldr tar`).
- `just` - run `justfile` recipes (modern `make`).

## Runtimes (mise)

`mise` owns Node and Python versions. Globals live in `home/.config/mise/config.toml` (Node 22, Python 3.13). Per-project overrides go in a `.mise.toml` at the project root:

```toml
[tools]
node = "20"
python = "3.12"
```

`mise install` installs what the current directory asks for; `mise x node -- node -v` runs a one-off.

## Multiplexer (herdr)

Prefix is `Ctrl+B`. From `home/.config/herdr/config.toml`:

| Key                | Action                                               |
| ------------------ | ---------------------------------------------------- |
| `prefix + "`       | Split horizontal                                     |
| `prefix + %`       | Split vertical                                       |
| `prefix + h/j/k/l` | Focus left/down/up/right                             |
| `prefix + c`       | New tab                                              |
| `prefix + &`       | Close tab                                            |
| `prefix + w`       | Workspace picker                                     |
| `prefix + g`       | Goto                                                 |
| `prefix + y`       | Copy mode (v/Space select, y/Enter copy, q/Esc exit) |

## Making changes

Edit any file under `home/` - it's symlinked into place, so the change is live immediately. Run `./rebuild.sh` only when you change a package list, a system default, or anything in `home.nix` / `configuration.nix` / `flake.nix`.
