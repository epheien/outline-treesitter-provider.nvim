local utils = require('outline.providers.treesitter.utils')
local config = {}

local M = {}

M.fetch_symbols_sync = function(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  local items = {}
  local last_header
  local prev_lnum = 0
  local prev_line = ""
  local function finalize_header()
    if last_header then
      last_header.range['end'].line = prev_lnum - 1
      last_header.range['end'].character = prev_line:len()
    end
  end
  for lnum, line in ipairs(lines) do
    local header = line:match("^[A-Z].+")
    local padding, arg = line:match("^(%s+)(-.+)")
    if header and lnum > 1 then
      finalize_header()
      local item = {
        kind = utils.to_kind("Interface"),
        name = header,
        level = 0,
        range = {
          start = { line = lnum - 1, character = 0 },
          ['end'] = { line = lnum - 1, character = 10000 },
        },
      }
      item.selectionRange = item.range
      if
          not config.post_parse_symbol
          or config.post_parse_symbol(bufnr, item, {
            backend_name = "man",
            lang = "man",
          })
          ~= false
      then
        last_header = item
        table.insert(items, item)
      end
    elseif arg then
      local item = {
        kind = utils.to_kind("Interface"),
        name = arg,
        level = last_header and 1 or 0,
        parent = last_header,
        range = {
          start = { line = lnum - 1, character = padding:len() },
          ['end'] = { line = lnum - 1, character = line:len() },
        },
      }
      item.selectionRange = item.range
      if
          not config.post_parse_symbol
          or config.post_parse_symbol(bufnr, item, {
            backend_name = "man",
            lang = "man",
          })
          ~= false
      then
        if last_header then
          last_header.children = last_header.children or {}
          table.insert(last_header.children, item)
        else
          table.insert(items, item)
        end
      end
    end
    prev_lnum = lnum
    prev_line = line
  end
  finalize_header()
  return items
end

function M.get_symbols(parser, buf)
  return M.fetch_symbols_sync(buf)
end

return M
