# An outline.nvim external provider for treesitter

Port treesitter support of [symbols.nvim](https://github.com/oskarrrrrrr/symbols.nvim) and
[aerial.nvim](https://github.com/stevearc/aerial.nvim) to [outline.nvim](https://github.com/hedyhli/outline.nvim).

A Lazy.nvim example to use this provider.

```lua
  {
    'hedyhli/outline.nvim',
    config = function()
      require('outline').setup({
        providers = {
          priority = { 'lsp', 'coc', 'markdown', 'norg', 'treesitter' },
        },
      })
    end,
    event = "VeryLazy",
    dependencies = {
      'epheien/outline-treesitter-provider.nvim'
    }
  }
```

## NOTES

This plugin is far from mature. If you find any issues, please submit an issue, PR is even better.
