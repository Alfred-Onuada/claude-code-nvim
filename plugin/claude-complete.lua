-- claude-complete.nvim plugin entry point
-- This file is automatically loaded by Neovim

-- Prevent loading twice
if vim.g.loaded_claude_complete then
	return
end
vim.g.loaded_claude_complete = true

-- Check Neovim version
if vim.fn.has("nvim-0.9.0") ~= 1 then
	vim.notify("[claude-complete] Requires Neovim >= 0.9.0", vim.log.levels.ERROR)
	return
end

-- Check for curl
if vim.fn.executable("curl") ~= 1 then
	vim.notify("[claude-complete] Requires curl to be installed", vim.log.levels.ERROR)
	return
end

-- The plugin is lazy-loaded when setup() is called
-- Users should call: require('claude-complete').setup({})
