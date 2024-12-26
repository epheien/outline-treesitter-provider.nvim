local helpers = require("outline.providers.treesitter.aerial.helpers")
local to_outline_range = helpers.to_outline_range

local M = {}

-- Custom capture groups:
-- symbol: Used to determine to unique node that represents the symbol
-- name (optional): The text of this node will be used in the display
-- start (optional): The location of the start of this symbol (default @symbol)
-- end (optional): The location of the end of this symbol (default @start)

M.is_supported = function(bufnr)
  if vim.fn.has("nvim-0.9") == 0 and not pcall(require, "nvim-treesitter") then
    return false, "Neovim <0.9 requires nvim-treesitter"
  end
  local lang = helpers.get_buf_lang(bufnr)
  if not helpers.has_parser(lang) then
    return false, string.format("No treesitter parser for %s", lang)
  end
  if helpers.get_query(lang) == nil then
    return false, string.format("No queries defined for '%s'", lang)
  end
  return true, nil
end

M.fetch_symbols_sync = function(bufnr)
  bufnr = bufnr or 0
  local extensions = require("outline.providers.treesitter.aerial.extensions")
  local get_node_text = vim.treesitter.get_node_text
  local parser = helpers.get_parser(bufnr)
  local items = {}
  if not parser then
    return
  end
  local lang = parser:lang()
  local syntax_tree = parser:parse()[1]
  local query = helpers.get_query(lang)
  if not query or not syntax_tree then
    return
  end
  -- This will track a loose hierarchy of recent node+items.
  -- It is used to determine node parents for the tree structure.
  local stack = {}
  local ext = extensions[lang]
  ---@diagnostic disable-next-line: missing-parameter
  for _, matches, metadata in query:iter_matches(syntax_tree:root(), bufnr) do
    ---@note mimic nvim-treesitter's query.iter_group_results return values:
    --       {
    --         kind = "Method",
    --         name = {
    --           metadata = {
    --             range = { 2, 11, 2, 20 }
    --           },
    --           node = <userdata 1>
    --         },
    --         type = {
    --           node = <userdata 2>
    --         }
    --       }
    --- Matches can overlap. The last match wins.
    local match = vim.tbl_extend("force", {}, metadata)
    for id, node in pairs(matches) do
      -- iter_group_results prefers `#set!` metadata, keeping the behaviour
      match = vim.tbl_extend("keep", match, {
        [query.captures[id]] = {
          metadata = metadata[id],
          node = node,
        },
      })
    end

    local name_match = match.name or {}
    local selection_match = match.selection or {}
    local symbol_node = (match.symbol or match.type or {}).node
    -- The location capture groups are optional. We default to the
    -- location of the @symbol capture
    local start_node = (match.start or {}).node or symbol_node
    local end_node = (match["end"] or {}).node or start_node
    local parent_item, parent_node, level = ext.get_parent(stack, match, symbol_node)
    -- Sometimes our queries will match the same node twice.
    -- Detect that (symbol_node == parent_node), and skip dupes.
    if not symbol_node or symbol_node == parent_node then
      goto continue
    end
    local kind = match.kind
    if not kind then
      vim.api.nvim_err_writeln(
        string.format("Missing 'kind' metadata in query file for language %s", lang)
      )
      break
    elseif not vim.lsp.protocol.SymbolKind[kind] then
      vim.api.nvim_err_writeln(
        string.format("Invalid 'kind' metadata '%s' in query file for language %s", kind, lang)
      )
      break
    end
    local range = helpers.range_from_nodes(start_node, end_node)
    local selection_range
    if selection_match.node then
      selection_range = helpers.range_from_nodes(selection_match.node, selection_match.node)
    end
    local name
    if name_match.node then
      name = get_node_text(name_match.node, bufnr, name_match) or "<parse error>"
      if not selection_range then
        selection_range = helpers.range_from_nodes(name_match.node, name_match.node)
      end
    else
      name = "<Anonymous>"
    end
    local scope
    if match.scope and match.scope.node then -- we've got a node capture on our hands
      scope = get_node_text(match.scope.node, bufnr, match.scope)
    else
      scope = match.scope
    end
    local outline_range = to_outline_range(selection_range)
    ---@type aerial.Symbol
    local item = {
      kind = kind,
      name = name,
      level = level,
      parent = parent_item,
      selection_range = selection_range,
      scope = scope,
      range = outline_range,
      selectionRange = outline_range, -- FIXME: patch outline.nvim to ignore selectionRange
    }
    for k, v in pairs(range) do
      item[k] = v
    end
    if ext.postprocess(bufnr, item, match) == false then
      goto continue
    end
    if item.parent then
      if not item.parent.children then
        item.parent.children = {}
      end
      table.insert(item.parent.children, item)
    else
      table.insert(items, item)
    end
    table.insert(stack, { node = symbol_node, item = item })

    ::continue::
  end
  ext.postprocess_symbols(bufnr, items)
  return items
end

function M.supports_buffer(bufnr)
  local ok, msg = M.is_supported(bufnr) ---@diagnostic disable-line
  --if not ok then vim.notify('outline.providers.treesitter: ' .. msg, vim.log.levels.WARN) end
  return ok, { buf = bufnr }
end

---@param on_symbols fun(symbols?:outline.ProviderSymbol[], opts?:table)
---@param opts table?
---@param info table? Must be the table received from `supports_buffer`
function M.request_symbols(on_symbols, opts, info)
  local symbols = M.fetch_symbols_sync(info.buf) ---@diagnostic disable-line
  on_symbols(symbols, opts)
end

return M
