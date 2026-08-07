return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      ensure_installed = {
        'go', 'gomod', 'gosum',
        'lua', 'luadoc',
        'python',
        'typescript', 'tsx', 'javascript',
        'nix',
        'bash',
        'json', 'yaml', 'toml',
        'markdown', 'markdown_inline',
        'vim', 'vimdoc', 'query',
      },
      highlight = { enable = true },
      indent = { enable = true },
    },
    config = function(_, opts)
      require('nvim-treesitter.configs').setup(opts)
    end,
  },
}
