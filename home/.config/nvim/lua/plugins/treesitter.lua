-- nvim-treesitter main branch (the full rewrite) dropped the legacy
-- `require('nvim-treesitter.configs')` module. Highlighting is now built into
-- Neovim via `vim.treesitter.start()`; this plugin just installs parsers and
-- provides queries + an experimental indentexpr.
local languages = {
  'go', 'gomod', 'gosum',
  'lua', 'luadoc',
  'python',
  'typescript', 'tsx', 'javascript',
  'nix',
  'bash',
  'json', 'yaml', 'toml',
  'markdown', 'markdown_inline',
  'vim', 'vimdoc', 'query',
}

return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    -- The rewrite does not support lazy loading.
    lazy = false,
    config = function()
      require('nvim-treesitter').setup {}

      -- Install parsers asynchronously; no-op when already present.
      require('nvim-treesitter').install(languages)

      -- Enable treesitter highlighting and indentation for any buffer that
      -- has a parser available (equivalent to the old `highlight`/`indent`
      -- `enable = true` for all installed parsers).
      vim.api.nvim_create_autocmd('FileType', {
        pattern = '*',
        callback = function()
          if pcall(vim.treesitter.start) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
