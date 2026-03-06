-- Ghost text rendering for claude-complete.nvim
local M = {}

local config = require("claude-complete.config")

-- Namespace for extmarks
M.ns_id = vim.api.nvim_create_namespace("claude_complete_ghost")

-- Current ghost text state
M.current = {
  bufnr = nil,
  text = nil,
  row = nil,
  col = nil,
  extmark_ids = {},
}

-- Clear all ghost text
function M.clear()
  if M.current.bufnr and vim.api.nvim_buf_is_valid(M.current.bufnr) then
    vim.api.nvim_buf_clear_namespace(M.current.bufnr, M.ns_id, 0, -1)
  end

  M.current = {
    bufnr = nil,
    text = nil,
    row = nil,
    col = nil,
    extmark_ids = {},
  }
end

-- Show ghost text at cursor position
function M.show(text, bufnr, row, col)
  if not text or text == "" then
    M.clear()
    return
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  row = row or cursor[1]
  col = col or cursor[2]

  -- Clear previous ghost text
  M.clear()

  local cfg = config.get()
  local hl_group = cfg.ghost_text.hl_group
  local priority = cfg.ghost_text.priority

  -- Split text into lines
  local lines = vim.split(text, "\n", { plain = true })

  -- Store state
  M.current.bufnr = bufnr
  M.current.text = text
  M.current.row = row
  M.current.col = col
  M.current.extmark_ids = {}

  -- Get current line content
  local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""

  -- First line: show as virtual text after cursor
  local first_line = lines[1] or ""
  if first_line ~= "" then
    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, row - 1, col, {
      virt_text = { { first_line, hl_group } },
      virt_text_pos = "inline",
      priority = priority,
      hl_mode = "combine",
    })
    table.insert(M.current.extmark_ids, extmark_id)
  end

  -- Additional lines: show as virtual lines below
  if #lines > 1 then
    local virt_lines = {}
    for i = 2, #lines do
      table.insert(virt_lines, { { lines[i], hl_group } })
    end

    if #virt_lines > 0 then
      local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, row - 1, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
        priority = priority,
      })
      table.insert(M.current.extmark_ids, extmark_id)
    end
  end
end

-- Update ghost text (for streaming)
function M.update(text)
  if M.current.bufnr and M.current.row and M.current.col then
    M.show(text, M.current.bufnr, M.current.row, M.current.col)
  end
end

-- Get current ghost text
function M.get_text()
  return M.current.text
end

-- Check if ghost text is visible
function M.is_visible()
  return M.current.text ~= nil and M.current.text ~= ""
end

-- Accept ghost text (insert into buffer)
function M.accept()
  if not M.is_visible() then
    return false
  end

  local bufnr = M.current.bufnr
  local text = M.current.text
  local row = M.current.row
  local col = M.current.col

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    M.clear()
    return false
  end

  -- Clear ghost text first
  M.clear()

  -- Schedule buffer modification to avoid E565 in restricted contexts
  vim.schedule(function()
    -- Verify we're still in the right buffer and position
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    -- Get current line
    local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""

    -- Split insertion text into lines
    local lines = vim.split(text, "\n", { plain = true })

    if #lines == 1 then
      -- Single line: insert at cursor position
      local new_line = current_line:sub(1, col) .. text .. current_line:sub(col + 1)
      vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
      -- Move cursor to end of inserted text
      vim.api.nvim_win_set_cursor(0, { row, col + #text })
    else
      -- Multiple lines
      local first_line = current_line:sub(1, col) .. lines[1]
      local last_line = lines[#lines] .. current_line:sub(col + 1)

      local new_lines = { first_line }
      for i = 2, #lines - 1 do
        table.insert(new_lines, lines[i])
      end
      table.insert(new_lines, last_line)

      vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, new_lines)
      -- Move cursor to end of inserted text
      vim.api.nvim_win_set_cursor(0, { row + #lines - 1, #lines[#lines] })
    end
  end)

  return true
end

-- Accept first word of ghost text
function M.accept_word()
  if not M.is_visible() then
    return false
  end

  local text = M.current.text

  -- Find first word boundary
  local word_end = text:match("^(%S+)")
  if not word_end then
    -- All whitespace, accept first whitespace chunk
    word_end = text:match("^(%s+)")
  end

  if not word_end then
    return false
  end

  local bufnr = M.current.bufnr
  local row = M.current.row
  local col = M.current.col
  local remaining = text:sub(#word_end + 1)

  -- Clear ghost text
  M.clear()

  -- Schedule buffer modification
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    -- Insert word
    local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    local new_line = current_line:sub(1, col) .. word_end .. current_line:sub(col + 1)
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
    vim.api.nvim_win_set_cursor(0, { row, col + #word_end })

    -- Show remaining text
    if remaining ~= "" then
      M.show(remaining, bufnr, row, col + #word_end)
    end
  end)

  return true
end

-- Accept first line of ghost text
function M.accept_line()
  if not M.is_visible() then
    return false
  end

  local text = M.current.text
  local lines = vim.split(text, "\n", { plain = true })

  if #lines == 0 then
    return false
  end

  local first_line = lines[1]
  local bufnr = M.current.bufnr
  local row = M.current.row
  local col = M.current.col

  -- Clear ghost text
  M.clear()

  -- Schedule buffer modification
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    -- Insert first line
    local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    local new_line = current_line:sub(1, col) .. first_line .. current_line:sub(col + 1)
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })
    vim.api.nvim_win_set_cursor(0, { row, col + #first_line })

    -- Show remaining lines
    if #lines > 1 then
      local remaining_lines = {}
      for i = 2, #lines do
        table.insert(remaining_lines, lines[i])
      end
      local remaining = table.concat(remaining_lines, "\n")
      if remaining ~= "" then
        M.show(remaining, bufnr, row, col + #first_line)
      end
    end
  end)

  return true
end

return M
