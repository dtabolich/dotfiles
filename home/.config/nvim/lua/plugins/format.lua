-- Format on save. Formatters are external binaries installed via Nix (home.nix);
-- conform.nvim just shells out to them, so no Mason needed.
return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    opts = {
      formatters_by_ft = {
        go = { 'gofmt' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        nix = { 'nixpkgs_fmt' },
        lua = { 'stylua' },
        sh = { 'shfmt' },
        javascript = { 'prettier' },
        typescript = { 'prettier' },
        typescriptreact = { 'prettier' },
        json = { 'prettier' },
        yaml = { 'prettier' },
        markdown = { 'prettier' },
        toml = { 'taplo' },
      },
      format_on_save = { timeout_ms = 2000, lsp_fallback = true },
    },
  },
}
