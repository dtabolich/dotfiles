-- Completion first so lspconfig can pick up its capabilities.
return {
  {
    'saghen/blink.cmp',
    version = '*',
    opts = {
      keymap = { preset = 'default' },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      signature = { enabled = true },
    },
  },
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = { 'saghen/blink.cmp' },
    config = function()
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      local on_attach = function(_, bufnr)
        local map = function(lhs, rhs, desc)
          vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map('K', vim.lsp.buf.hover, 'Hover Doc')
        map('gD', vim.lsp.buf.declaration, 'Goto Declaration')
        map('gi', vim.lsp.buf.implementation, 'Goto Implementation')
        map('gr', function() Snacks.picker.lsp_references() end, 'References')
        map('<leader>ca', vim.lsp.buf.code_action, 'Code Action')
        map('<leader>rn', vim.lsp.buf.rename, 'Rename')
        map('<leader>d', vim.diagnostic.open_float, 'Line Diagnostics')
        map('[d', vim.diagnostic.goto_prev, 'Prev Diagnostic')
        map(']d', vim.diagnostic.goto_next, 'Next Diagnostic')
      end

      -- Servers are installed via Nix (home.nix); lspconfig just wires them up.
      -- nil_ls = nix, lua_ls = lua (nvim/wezterm config), ts_ls = typescript,
      -- taplo = toml (mise/direnv/starship), yamlls = yaml (k8s/CI configs).
      local servers = {
        gopls = {},
        pyright = {},
        nil_ls = {},
        marksman = {},
        ts_ls = {},
        taplo = {},
        yamlls = {},
        lua_ls = {
          settings = {
            Lua = { diagnostics = { globals = { 'vim', 'Snacks' } } },
          },
        },
      }

      for name, opts in pairs(servers) do
        vim.lsp.config(name, vim.tbl_deep_extend('force', {
          on_attach = on_attach,
          capabilities = capabilities,
        }, opts))
        vim.lsp.enable(name)
      end
    end,
  },
}
