local utils = require('outline.providers.treesitter.utils')

local Symbol_root = utils.Symbol_root

local M = {}

function M.get_symbols(parser, buf)
  local rootNode = parser:parse()[1]:root()
  local queryString = [[
        [
            (h1 (heading) @H1)
            (h2 (heading) @H2)
            (h3 (heading) @H3)
            (tag text: (word) @Tag)
        ]
    ]]
  local query = vim.treesitter.query.parse("vimdoc", queryString)
  local kind_to_capture_level = { root = 0, H1 = 1, H2 = 2, H3 = 3, Tag = 4 }
  local root = Symbol_root()
  local current = root
  for id, node, _, _ in query:iter_captures(rootNode, 0) do
    local kind = query.captures[id]
    local row1, col1, row2, col2 = node:range()
    local name = vim.api.nvim_buf_get_text(buf, row1, col1, row2, col2, {})[1]
    local level = kind_to_capture_level[kind]
    local range = {
      ["start"] = { line = row1, character = col1 },
      ["end"] = { line = row2, character = col2 },
    }
    if (
          kind == "Tag" and current.kind_name == "Tag"
          and range.start.line == current.range.start.line
        ) then
      current.name = current.name .. " " .. name
    else
      while level <= kind_to_capture_level[current.kind_name] do
        current = current.parent
        assert(current ~= nil)
      end
      local new = {
        kind_name = kind,
        kind = utils.to_kind(kind),
        name = name,
        detail = "",
        level = level,
        parent = current,
        children = {},
        range = range,
        selectionRange = range,
      }
      table.insert(current.children, new)
      current = new
    end
  end

  local function fix_range_ends(node, range_end)
    if node.kind_name == "Tag" then return end
    node.range["end"].line = range_end
    for i, child in ipairs(node.children) do
      local new_range_end = range_end
      if node.children[i + 1] ~= nil then
        new_range_end = node.children[i + 1].range["start"].line - 1 or range_end
      end
      fix_range_ends(child, new_range_end)
    end
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  fix_range_ends(root, line_count)

  return true, root.children
end

return M
