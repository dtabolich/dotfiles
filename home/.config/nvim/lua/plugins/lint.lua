-- Lightweight linters; nvim-lint shells out to binaries installed via Nix.
return {
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      local lint = require('lint')
      lint.linters_by_ft = {
        go = { 'golangcilint' },
        python = { 'ruff' },
        sh = { 'shellcheck' },
        nix = { 'statix' },
      }
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufEnter' }, {
        callback = function() lint.try_lint() end,
      })
    end,
  },
}
