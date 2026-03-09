-- Completion management for claude-complete.nvim
local M = {}

local config = require("claude-complete.config")
local api = require("claude-complete.api")
local context = require("claude-complete.context")
local ghost = require("claude-complete.ghost")

-- Debounce timer
M.timer = nil

-- State
M.state = {
	enabled = true,
	requesting = false,
	last_cursor = nil,
}

-- Cancel any pending request and timer
function M.cancel()
	if M.timer then
		M.timer:stop()
		M.timer:close()
		M.timer = nil
	end
	api.cancel()
	M.state.requesting = false
end

-- Trigger completion after debounce
function M.trigger()
	local cfg = config.get()

	if not cfg.enabled or not M.state.enabled then
		return
	end

	if not config.is_configured() then
		return
	end

	-- Cancel any existing request
	M.cancel()

	-- Get cursor position for tracking
	local cursor = vim.api.nvim_win_get_cursor(0)
	M.state.last_cursor = { cursor[1], cursor[2] }

	-- Create debounce timer
	M.timer = vim.uv.new_timer()
	M.timer:start(
		cfg.debounce_ms,
		0,
		vim.schedule_wrap(function()
			M.request_completion()
		end)
	)
end

-- Make the actual completion request
function M.request_completion()
	-- Clear timer reference
	M.timer = nil

	local cfg = config.get()

	-- Check if cursor moved since trigger
	local cursor = vim.api.nvim_win_get_cursor(0)
	if M.state.last_cursor then
		if cursor[1] ~= M.state.last_cursor[1] or cursor[2] ~= M.state.last_cursor[2] then
			-- Cursor moved, don't complete
			return
		end
	end

	-- Check if we're in insert mode
	local mode = vim.api.nvim_get_mode().mode
	if mode ~= "i" and mode ~= "ic" then
		return
	end

	-- Build context
	local ctx = context.build_context()

	-- Don't complete if cursor is at start of file or line is empty
	if ctx.before_cursor == "" or ctx.before_cursor:match("^%s*$") then
		return
	end

	M.state.requesting = true

	-- Clear any existing ghost text
	ghost.clear()

	-- Make API request
	api.complete(
		ctx,
		-- on_chunk: stream ghost text as it arrives
		function(chunk, accumulated)
			-- Check if still relevant
			if not M.state.requesting then
				return
			end

			local current_cursor = vim.api.nvim_win_get_cursor(0)
			if current_cursor[1] ~= cursor[1] or current_cursor[2] ~= cursor[2] then
				-- Cursor moved, cancel
				api.cancel()
				ghost.clear()
				M.state.requesting = false
				return
			end

			-- Update ghost text
			ghost.show(accumulated, nil, cursor[1], cursor[2])
		end,
		-- on_done
		function(final_text)
			M.state.requesting = false

			if cfg.debug then
				vim.notify("[claude-complete] Completion received: " .. #final_text .. " chars", vim.log.levels.DEBUG)
			end
		end,
		-- on_error
		function(err)
			M.state.requesting = false
			ghost.clear()

			if cfg.debug then
				vim.notify("[claude-complete] Error: " .. tostring(err), vim.log.levels.ERROR)
			end
		end
	)
end

-- Handle text change in insert mode
function M.on_text_changed()
	-- Clear ghost text on any change
	ghost.clear()

	-- Trigger new completion
	M.trigger()
end

-- Handle cursor movement
function M.on_cursor_moved()
	-- If cursor moved and we have ghost text, clear it
	if ghost.is_visible() then
		local cursor = vim.api.nvim_win_get_cursor(0)
		if M.state.last_cursor then
			if cursor[1] ~= M.state.last_cursor[1] or cursor[2] ~= M.state.last_cursor[2] then
				ghost.clear()
				M.cancel()
			end
		end
	end
end

-- Handle leaving insert mode
function M.on_insert_leave()
	M.cancel()
	ghost.clear()
end

-- Accept current completion
function M.accept()
	if ghost.accept() then
		M.cancel()
		return true
	end
	return false
end

-- Accept word
function M.accept_word()
	return ghost.accept_word()
end

-- Accept line
function M.accept_line()
	return ghost.accept_line()
end

-- Dismiss current completion
function M.dismiss()
	M.cancel()
	ghost.clear()
end

-- Enable/disable completions
function M.enable()
	M.state.enabled = true
end

function M.disable()
	M.state.enabled = false
	M.cancel()
	ghost.clear()
end

function M.toggle()
	if M.state.enabled then
		M.disable()
	else
		M.enable()
	end
	return M.state.enabled
end

function M.is_enabled()
	return M.state.enabled
end

return M
