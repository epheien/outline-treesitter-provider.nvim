local M = {}
local query_cache = {}

--- convert aerial range to outline range
---@param aerial_range aerial.Range
---@return table|nil
function M.to_outline_range(aerial_range)
  -- 如果 aerial_range 不可用, 那表示使用 postprocess 扩展去填充, 例如 c
  if not aerial_range then return nil end
  return {
    start = { line = aerial_range.lnum - 1, character = aerial_range.col },
    ['end'] = { line = aerial_range.end_lnum - 1, character = aerial_range.end_col, },
  }
end

--@note Clear query cache, forcing reload
M.clear_query_cache = function()
  query_cache = {}
end

---@param start_node TSNode
---@param end_node TSNode
---@return aerial.Range
M.range_from_nodes = function(start_node, end_node)
  local row, col = start_node:start()
  local end_row, end_col = end_node:end_()
  return {
    lnum = row + 1,
    end_lnum = end_row + 1,
    col = col,
    end_col = end_col,
  }
end

if vim.treesitter.language.get_lang == nil then
  ---@param bufnr nil|integer
  M.get_buf_lang = function(bufnr)
    return require("nvim-treesitter.parsers").get_buf_lang(bufnr)
  end
else
  -- Taken directly out of nvim-treesitter with minor adjustments
  ---@param bufnr nil|integer
  M.get_buf_lang = function(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ft = vim.bo[bufnr].filetype

    local result = vim.treesitter.language.get_lang(ft)
    if result then
      return result
    else
      ft = vim.split(ft, ".", { plain = true })[1]
      return vim.treesitter.language.get_lang(ft) or ft
    end
  end
end

if vim.treesitter.query.get == nil then
  ---@param lang string
  ---@return vim.treesitter.Query|nil
  M.load_query = function(lang)
    ---@diagnostic disable-next-line: deprecated
    return vim.treesitter.query.get_query(lang, "aerial")
  end
else
  ---@param lang string
  ---@return vim.treesitter.Query|nil
  M.load_query = function(lang)
    return vim.treesitter.query.get(lang, "aerial")
  end
end

---@param lang string
---@return vim.treesitter.Query|nil
---@note caches queries to avoid filesystem hits on neovim 0.9+
M.get_query = function(lang)
  if not query_cache[lang] then
    query_cache[lang] = { query = M.load_query(lang) }
  end

  return query_cache[lang].query
end

---@param lang string
---@return boolean
M.has_parser = function(lang)
  local installed, _ = pcall(vim.treesitter.get_string_parser, "", lang)

  return installed
end

---@param bufnr integer
---@return vim.treesitter.LanguageTree|nil
M.get_parser = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  ---@note nvim 0.9.1 and later don't really care for lang here, as vim itself becomes an authority on that
  ---      nvim 0.8.3 breaks if we are too eager, however
  local lang = M.get_buf_lang(bufnr)
  local success, parser = pcall(vim.treesitter.get_parser, bufnr, lang)

  return success and parser or nil
end

return M
