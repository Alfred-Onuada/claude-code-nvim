-- Configuration management for claude-complete.nvim
local M = {}

-- Default configuration
M.defaults = {
	api_key = nil,
	model = "claude-haiku-4-5-20251001",
	max_tokens = 256,
	debounce_ms = 150,
	context = {
		max_lines = 1000,
		include_imports = true,
		include_buffer_names = true,
		max_import_size = 500, -- max lines per imported file
	},
	ghost_text = {
		hl_group = "Comment",
		priority = 1000,
	},
	keymaps = {
		accept = "<Tab>",
		dismiss = "<Esc>",
		accept_word = "<C-Right>",
		accept_line = "<C-Down>",
	},
	enabled = true,
	debug = false,
}

-- Current configuration (merged with defaults)
M.options = {}

-- Config file path in nvim config directory
local function get_config_path()
	local config_dir = vim.fn.stdpath("config")
	return config_dir .. "/claude-complete.json"
end

-- Load API key from config file
local function load_config_file()
	local path = get_config_path()
	local file = io.open(path, "r")
	if not file then
		return {}
	end

	local content = file:read("*a")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		vim.notify("[claude-complete] Failed to parse config file", vim.log.levels.WARN)
		return {}
	end

	return data or {}
end

-- Save config to file with secure permissions
local function save_config_file(data)
	local path = get_config_path()

	-- Encode to JSON
	local ok, content = pcall(vim.json.encode, data)
	if not ok then
		vim.notify("[claude-complete] Failed to encode config", vim.log.levels.ERROR)
		return false
	end

	-- Write to file
	local file = io.open(path, "w")
	if not file then
		vim.notify("[claude-complete] Failed to write config file", vim.log.levels.ERROR)
		return false
	end

	file:write(content)
	file:close()

	-- Set secure permissions (owner read/write only)
	vim.fn.system({ "chmod", "600", path })

	return true
end

-- Deep merge tables
local function deep_merge(t1, t2)
	local result = vim.deepcopy(t1)
	for k, v in pairs(t2) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = deep_merge(result[k], v)
		else
			result[k] = v
		end
	end
	return result
end

-- Setup configuration
function M.setup(opts)
	opts = opts or {}

	-- Load from config file first
	local file_config = load_config_file()

	-- Merge: defaults < file_config < user opts
	M.options = deep_merge(M.defaults, file_config)
	M.options = deep_merge(M.options, opts)

	-- Check for environment variable as highest priority for API key
	local env_key = vim.env.ANTHROPIC_API_KEY
	if env_key and env_key ~= "" then
		M.options.api_key = env_key
	end

	return M.options
end

-- Get current config
function M.get()
	return M.options
end

-- Get API key
function M.get_api_key()
	return M.options.api_key
end

-- Set API key and save to config file
function M.set_api_key(key)
	M.options.api_key = key

	-- Save to config file
	local file_config = load_config_file()
	file_config.api_key = key
	return save_config_file(file_config)
end

-- Set model
function M.set_model(model)
	M.options.model = model

	-- Save to config file
	local file_config = load_config_file()
	file_config.model = model
	return save_config_file(file_config)
end

-- Check if plugin is properly configured
function M.is_configured()
	return M.options.api_key ~= nil and M.options.api_key ~= ""
end

-- Get config file path (for display purposes)
function M.get_config_file_path()
	return get_config_path()
end

return M
