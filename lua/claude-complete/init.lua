-- claude-complete.nvim - AI-powered inline code completion
local M = {}

local config = require("claude-complete.config")
local completion = require("claude-complete.completion")
local context = require("claude-complete.context")
local api = require("claude-complete.api")
local ghost = require("claude-complete.ghost")

-- Plugin version
M.version = "0.1.0"

-- Setup autocommands
local function setup_autocmds()
	local group = vim.api.nvim_create_augroup("ClaudeComplete", { clear = true })

	-- Trigger completion on text change in insert mode
	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		callback = function()
			completion.on_text_changed()
		end,
	})

	-- Handle cursor movement in insert mode
	vim.api.nvim_create_autocmd("CursorMovedI", {
		group = group,
		callback = function()
			completion.on_cursor_moved()
		end,
	})

	-- Clear on leaving insert mode
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function()
			completion.on_insert_leave()
		end,
	})

	-- Pre-fetch imports when opening a buffer
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		callback = function(args)
			vim.schedule(function()
				context.prefetch_imports(args.buf)
			end)
		end,
	})

	-- Invalidate cache on file save
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		callback = function(args)
			local filepath = vim.api.nvim_buf_get_name(args.buf)
			context.invalidate_file(filepath)
		end,
	})
end

-- Setup keymaps
local function setup_keymaps()
	local cfg = config.get()
	local keymaps = cfg.keymaps

	-- Accept completion with Tab (only when ghost text visible)
	vim.keymap.set("i", keymaps.accept, function()
		if ghost.is_visible() then
			vim.schedule(function()
				completion.accept()
			end)
			return ""
		end
		return keymaps.accept
	end, { expr = true, noremap = true, silent = true, desc = "Accept Claude completion" })

	-- Dismiss with Escape
	vim.keymap.set("i", keymaps.dismiss, function()
		if ghost.is_visible() then
			vim.schedule(function()
				completion.dismiss()
			end)
			return ""
		end
		return keymaps.dismiss
	end, { expr = true, noremap = true, silent = true, desc = "Dismiss Claude completion" })

	-- Accept word
	vim.keymap.set("i", keymaps.accept_word, function()
		if ghost.is_visible() then
			vim.schedule(function()
				completion.accept_word()
			end)
			return ""
		end
		return keymaps.accept_word
	end, { expr = true, noremap = true, silent = true, desc = "Accept word of Claude completion" })

	-- Accept line
	vim.keymap.set("i", keymaps.accept_line, function()
		if ghost.is_visible() then
			vim.schedule(function()
				completion.accept_line()
			end)
			return ""
		end
		return keymaps.accept_line
	end, { expr = true, noremap = true, silent = true, desc = "Accept line of Claude completion" })
end

-- Setup commands
local function setup_commands()
	-- Setup command (configure API key)
	vim.api.nvim_create_user_command("ClaudeCompleteSetup", function()
		vim.ui.input({ prompt = "Enter Anthropic API key: " }, function(input)
			if input and input ~= "" then
				if config.set_api_key(input) then
					-- Verify the key
					api.health_check(function(ok, msg)
						if ok then
							vim.notify("[claude-complete] " .. msg, vim.log.levels.INFO)
						else
							vim.notify("[claude-complete] " .. msg, vim.log.levels.WARN)
						end
					end)
				else
					vim.notify("[claude-complete] Failed to save API key", vim.log.levels.ERROR)
				end
			end
		end)
	end, { desc = "Setup Claude Complete with API key" })

	-- Set model command
	vim.api.nvim_create_user_command("ClaudeCompleteModel", function(opts)
		if opts.args and opts.args ~= "" then
			config.set_model(opts.args)
			vim.notify("[claude-complete] Model set to: " .. opts.args, vim.log.levels.INFO)
		else
			vim.notify("[claude-complete] Current model: " .. config.get().model, vim.log.levels.INFO)
		end
	end, {
		nargs = "?",
		desc = "Set or show Claude model",
		complete = function()
			return {
				"claude-haiku-4-5-20251001",
				"claude-haiku-4-5",
				"claude-sonnet-4-6",
				"claude-opus-4-6",
				"claude-sonnet-4-5-20250929",
				"claude-opus-4-5-20251101",
			}
		end,
	})

	-- Enable/disable commands
	vim.api.nvim_create_user_command("ClaudeCompleteEnable", function()
		completion.enable()
		vim.notify("[claude-complete] Enabled", vim.log.levels.INFO)
	end, { desc = "Enable Claude Complete" })

	vim.api.nvim_create_user_command("ClaudeCompleteDisable", function()
		completion.disable()
		vim.notify("[claude-complete] Disabled", vim.log.levels.INFO)
	end, { desc = "Disable Claude Complete" })

	vim.api.nvim_create_user_command("ClaudeCompleteToggle", function()
		local enabled = completion.toggle()
		vim.notify("[claude-complete] " .. (enabled and "Enabled" or "Disabled"), vim.log.levels.INFO)
	end, { desc = "Toggle Claude Complete" })

	-- Status command
	vim.api.nvim_create_user_command("ClaudeCompleteStatus", function()
		local cfg = config.get()
		local lines = {
			"Claude Complete Status:",
			"  Enabled: " .. tostring(completion.is_enabled()),
			"  Configured: " .. tostring(config.is_configured()),
			"  Model: " .. cfg.model,
			"  Debounce: " .. cfg.debounce_ms .. "ms",
			"  Config file: " .. config.get_config_file_path(),
		}
		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end, { desc = "Show Claude Complete status" })

	-- Clear cache command
	vim.api.nvim_create_user_command("ClaudeCompleteClearCache", function()
		context.clear_cache()
		vim.notify("[claude-complete] Import cache cleared", vim.log.levels.INFO)
	end, { desc = "Clear Claude Complete import cache" })

	-- Health check command
	vim.api.nvim_create_user_command("ClaudeCompleteHealthCheck", function()
		if not config.is_configured() then
			vim.notify("[claude-complete] API key not configured. Run :ClaudeCompleteSetup", vim.log.levels.WARN)
			return
		end

		vim.notify("[claude-complete] Testing API connection...", vim.log.levels.INFO)
		api.health_check(function(ok, msg)
			if ok then
				vim.notify("[claude-complete] " .. msg, vim.log.levels.INFO)
			else
				vim.notify("[claude-complete] " .. msg, vim.log.levels.ERROR)
			end
		end)
	end, { desc = "Check Claude Complete API connection" })
end

-- Main setup function
function M.setup(opts)
	-- Initialize configuration
	config.setup(opts)

	-- Setup autocommands
	setup_autocmds()

	-- Setup keymaps
	setup_keymaps()

	-- Setup commands
	setup_commands()

	-- Log startup in debug mode
	local cfg = config.get()
	if cfg.debug then
		vim.notify("[claude-complete] Initialized with model: " .. cfg.model, vim.log.levels.DEBUG)
	end

	-- Warn if not configured
	if not config.is_configured() then
		vim.defer_fn(function()
			vim.notify(
				"[claude-complete] API key not configured. Run :ClaudeCompleteSetup or set ANTHROPIC_API_KEY",
				vim.log.levels.WARN
			)
		end, 1000)
	end
end

-- Expose sub-modules for advanced usage
M.config = config
M.completion = completion
M.context = context
M.api = api
M.ghost = ghost

return M
