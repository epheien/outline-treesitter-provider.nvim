local symbols = require('outline.symbols')

local M = {}

local character_max = 10000

function M.Symbol_root()
  return {
    kind_name = "root",
    kind = 28,
    name = "<root>",
    detail = "",
    level = 0,
    parent = nil,
    children = {},
    range = {
      start = { line = 0, character = 0 },
      ["end"] = { line = 0, character = character_max }
    },
    selectionRange = {
      start = { line = 0, character = 0 },
      ["end"] = { line = 0, character = character_max }
    },
  }
end

-- convert any to outline integer kind
function M.to_kind(kind)
  local int_kind = symbols.str_to_kind[kind]
  return int_kind or 28 -- 28 => Fragment
end

return M
