-- Context extraction for claude-complete.nvim
local M = {}

local config = require("claude-complete.config")

-- Cache for imported file contents
M.import_cache = {}

-- Import patterns for different languages
local import_patterns = {
  -- JavaScript/TypeScript
  javascript = {
    'import%s+.-%s+from%s+["\']([^"\']+)["\']',
    'require%s*%(%s*["\']([^"\']+)["\']%s*%)',
  },
  typescript = {
    'import%s+.-%s+from%s+["\']([^"\']+)["\']',
    'require%s*%(%s*["\']([^"\']+)["\']%s*%)',
  },
  typescriptreact = {
    'import%s+.-%s+from%s+["\']([^"\']+)["\']',
    'require%s*%(%s*["\']([^"\']+)["\']%s*%)',
  },
  javascriptreact = {
    'import%s+.-%s+from%s+["\']([^"\']+)["\']',
    'require%s*%(%s*["\']([^"\']+)["\']%s*%)',
  },

  -- Python
  python = {
    "^import%s+([%w_%.]+)",
    "^from%s+([%w_%.]+)%s+import",
  },

  -- Lua
  lua = {
    'require%s*%(?["\']([^"\']+)["\']%)?',
  },

  -- Go
  go = {
    '"([^"]+)"', -- inside import block
  },

  -- Rust
  rust = {
    "use%s+([%w_:]+)",
    "mod%s+([%w_]+)",
  },

  -- Ruby
  ruby = {
    'require%s+["\']([^"\']+)["\']',
    'require_relative%s+["\']([^"\']+)["\']',
  },

  -- C/C++
  c = {
    '#include%s*[<"]([^>"]+)[>"]',
  },
  cpp = {
    '#include%s*[<"]([^>"]+)[>"]',
  },
}

-- File extensions for languages
local extension_map = {
  javascript = { ".js", ".mjs" },
  typescript = { ".ts", ".tsx" },
  typescriptreact = { ".tsx" },
  javascriptreact = { ".jsx" },
  python = { ".py" },
  lua = { ".lua" },
  go = { ".go" },
  rust = { ".rs" },
  ruby = { ".rb" },
  c = { ".c", ".h" },
  cpp = { ".cpp", ".hpp", ".cc", ".hh" },
}

-- Resolve import path to actual file
local function resolve_import_path(import_path, current_file, filetype)
  local current_dir = vim.fn.fnamemodify(current_file, ":h")

  -- Handle relative imports
  if import_path:match("^%.") then
    local resolved = current_dir .. "/" .. import_path:gsub("^%.+/", "")

    -- Try with extensions
    local extensions = extension_map[filetype] or {}
    for _, ext in ipairs(extensions) do
      local full_path = resolved .. ext
      if vim.fn.filereadable(full_path) == 1 then
        return full_path
      end
    end

    -- Try as-is
    if vim.fn.filereadable(resolved) == 1 then
      return resolved
    end

    -- Try index file
    for _, ext in ipairs(extensions) do
      local index_path = resolved .. "/index" .. ext
      if vim.fn.filereadable(index_path) == 1 then
        return index_path
      end
    end
  end

  -- Handle absolute imports (check in workspace)
  local workspace = vim.fn.getcwd()
  local candidates = {
    workspace .. "/" .. import_path,
    workspace .. "/src/" .. import_path,
    workspace .. "/lib/" .. import_path,
  }

  local extensions = extension_map[filetype] or {}

  for _, base in ipairs(candidates) do
    for _, ext in ipairs(extensions) do
      local full_path = base .. ext
      if vim.fn.filereadable(full_path) == 1 then
        return full_path
      end
    end
    if vim.fn.filereadable(base) == 1 then
      return base
    end
  end

  return nil
end

-- Extract imports from buffer content
local function extract_imports(content, filetype)
  local patterns = import_patterns[filetype]
  if not patterns then
    return {}
  end

  local imports = {}
  local seen = {}

  for line in content:gmatch("[^\n]+") do
    for _, pattern in ipairs(patterns) do
      local match = line:match(pattern)
      if match and not seen[match] then
        seen[match] = true
        table.insert(imports, match)
      end
    end
  end

  return imports
end

-- Read file with line limit
local function read_file_limited(filepath, max_lines)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end

  local lines = {}
  local count = 0

  for line in file:lines() do
    count = count + 1
    if count > max_lines then
      break
    end
    table.insert(lines, line)
  end

  file:close()
  return table.concat(lines, "\n")
end

-- Get or cache imported file content
local function get_import_content(filepath, max_lines)
  -- Check cache
  local cached = M.import_cache[filepath]
  if cached then
    return cached
  end

  -- Read and cache
  local content = read_file_limited(filepath, max_lines)
  if content then
    M.import_cache[filepath] = content
  end

  return content
end

-- Pre-fetch imports for a buffer (call on buffer open)
function M.prefetch_imports(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cfg = config.get()
  if not cfg.context.include_imports then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  local imports = extract_imports(content, filetype)

  -- Resolve and cache imports
  for _, import_path in ipairs(imports) do
    local resolved = resolve_import_path(import_path, filepath, filetype)
    if resolved then
      get_import_content(resolved, cfg.context.max_import_size)
    end
  end
end

-- Get list of open buffer names
local function get_open_buffer_names()
  local buffers = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name and name ~= "" then
        -- Get relative path if possible
        local cwd = vim.fn.getcwd()
        if name:sub(1, #cwd) == cwd then
          name = name:sub(#cwd + 2)
        end
        table.insert(buffers, name)
      end
    end
  end

  return buffers
end

-- Build context for completion
function M.build_context(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cfg = config.get()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local col = cursor[2]

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local filename = vim.fn.fnamemodify(filepath, ":t")

  -- Get lines before cursor (limited)
  local start_line = math.max(0, row - cfg.context.max_lines)
  local lines_before = vim.api.nvim_buf_get_lines(bufnr, start_line, row - 1, false)

  -- Get current line
  local current_line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  local current_before_cursor = current_line:sub(1, col)
  local current_after_cursor = current_line:sub(col + 1)

  -- Combine content before cursor
  table.insert(lines_before, current_before_cursor)
  local before_cursor = table.concat(lines_before, "\n")

  -- Get content after cursor (rest of current line + lines below)
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local end_line = math.min(total_lines, row + cfg.context.max_lines)
  local lines_after = vim.api.nvim_buf_get_lines(bufnr, row, end_line, false)

  -- Combine content after cursor
  local after_cursor = current_after_cursor
  if #lines_after > 0 then
    after_cursor = current_after_cursor .. "\n" .. table.concat(lines_after, "\n")
  end

  -- Build extra context
  local extra_parts = {}

  -- Add import context
  if cfg.context.include_imports then
    local imports = extract_imports(before_cursor, filetype)
    local import_contents = {}

    for _, import_path in ipairs(imports) do
      local resolved = resolve_import_path(import_path, filepath, filetype)
      if resolved then
        local content = get_import_content(resolved, cfg.context.max_import_size)
        if content then
          local rel_path = vim.fn.fnamemodify(resolved, ":.")
          table.insert(import_contents, string.format("--- Imported: %s ---\n%s", rel_path, content))
        end
      end
    end

    if #import_contents > 0 then
      table.insert(extra_parts, "Imported files:\n" .. table.concat(import_contents, "\n\n"))
    end
  end

  -- Add buffer names
  if cfg.context.include_buffer_names then
    local buffers = get_open_buffer_names()
    if #buffers > 0 then
      table.insert(extra_parts, "Open files: " .. table.concat(buffers, ", "))
    end
  end

  return {
    filename = filename,
    filepath = filepath,
    filetype = filetype,
    before_cursor = before_cursor,
    after_cursor = after_cursor,
    extra_context = table.concat(extra_parts, "\n\n"),
    row = row,
    col = col,
  }
end

-- Clear import cache
function M.clear_cache()
  M.import_cache = {}
end

-- Clear cache for specific file
function M.invalidate_file(filepath)
  M.import_cache[filepath] = nil
end

return M
