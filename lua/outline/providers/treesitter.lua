---@diagnostic disable: need-check-nil
---@diagnostic disable: unused-local
local aerial = require('outline.providers.treesitter.aerial')

local M = {
  name = 'treesitter',
}

local ft_to_parser_name = {
  help = "vimdoc",
}

---@return boolean, table?
function M.supports_buffer(bufnr)
  --bufnr = bufnr ~= 0 and bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  local parser_name = ft_to_parser_name[ft]
  -- bypass to aerial treesitter
  if parser_name == nil then
    return aerial.supports_buffer(bufnr)
  end
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, parser_name)
  if not ok then return false end
  return true, { parser = parser, ft = ft, buf = bufnr, lang = parser_name }
end

---@param on_symbols fun(symbols?:outline.ProviderSymbol[], opts?:table)
---@param opts table?
---@param info table? Must be the table received from `supports_buffer`
function M.request_symbols(on_symbols, opts, info)
  -- bypass to aerial treesitter
  if not info.parser then
    return aerial.request_symbols(on_symbols, opts, info)
  end
  local ok, mod = pcall(require, 'outline.providers.treesitter.filetypes.' .. info.lang)
  assert(ok, "Failed to get `get_symbols` for ft: " .. tostring(info.ft))
  local symbols = mod.get_symbols(info.parser, info.buf)
  assert(vim.islist(symbols or {}), 'Internal error: symbols is not list!')
  on_symbols(symbols, opts)
end

return M
