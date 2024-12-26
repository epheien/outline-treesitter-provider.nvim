# An outline.nvim external provider for universal treesitter

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

## Configuration

### Default options
```lua
  {
  }
```

Please read the source code to obtain the latest default configuration.

## NOTES

This plugin is far from mature. If you find any issues, please submit an issue, PR is even better.
