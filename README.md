# claude-complete.nvim

AI-powered inline code completion for Neovim using Claude (Anthropic API).

## Features

- **Ghost text completions**: See suggestions inline as you type (like GitHub Copilot)
- **Streaming responses**: Completions appear progressively for minimal latency
- **Smart context**: Automatically includes imported files and open buffers
- **Configurable models**: Use Haiku for speed or Opus for quality
- **Zero dependencies**: Pure Lua, only requires curl

## Requirements

- Neovim >= 0.9.0
- curl
- Anthropic API key

## Installation

### lazy.nvim

```lua
{
  "Alfred-Onuada/claude-code-nvim",
  config = function()
    require("claude-complete").setup({
      -- your configuration here
    })
  end,
}
```

### packer.nvim

```lua
use {
  "Alfred-Onuada/claude-code-nvim",
  config = function()
    require("claude-complete").setup()
  end,
}
```

## Setup

1. Get an API key from [Anthropic Console](https://console.anthropic.com/)

2. Configure the API key (choose one method):

   **Option A: Environment variable (recommended)**
   ```bash
   export ANTHROPIC_API_KEY="your-api-key"
   ```

   **Option B: Setup command**
   ```vim
   :ClaudeCompleteSetup
   ```

3. Start typing! Completions will appear as ghost text after 300ms.

## Usage

### Keymaps (in insert mode)

| Key | Action |
|-----|--------|
| `<Tab>` | Accept full completion |
| `<Esc>` | Dismiss completion |
| `<C-Right>` | Accept next word |
| `<C-Down>` | Accept next line |

### Commands

| Command | Description |
|---------|-------------|
| `:ClaudeCompleteSetup` | Configure API key |
| `:ClaudeCompleteModel [model]` | Set or show current model |
| `:ClaudeCompleteEnable` | Enable completions |
| `:ClaudeCompleteDisable` | Disable completions |
| `:ClaudeCompleteToggle` | Toggle completions |
| `:ClaudeCompleteStatus` | Show current status |
| `:ClaudeCompleteHealthCheck` | Test API connection |
| `:ClaudeCompleteClearCache` | Clear import cache |

## Configuration

```lua
require("claude-complete").setup({
  -- API key (or use ANTHROPIC_API_KEY env var)
  api_key = nil,

  -- Model to use for completions
  -- Options: "claude-haiku-4-5-20251001" (fast), "claude-sonnet-4-6", "claude-opus-4-6"
  model = "claude-haiku-4-5-20251001",

  -- Maximum tokens to generate
  max_tokens = 256,

  -- Debounce delay in milliseconds
  debounce_ms = 300,

  -- Context settings
  context = {
    max_lines = 1000,           -- Max lines of current file to send
    include_imports = true,      -- Include imported file contents
    include_buffer_names = true, -- Include names of open buffers
    max_import_size = 500,       -- Max lines per imported file
  },

  -- Ghost text appearance
  ghost_text = {
    hl_group = "Comment",  -- Highlight group for ghost text
    priority = 1000,       -- Extmark priority
  },

  -- Keymaps (set to false to disable)
  keymaps = {
    accept = "<Tab>",
    dismiss = "<Esc>",
    accept_word = "<C-Right>",
    accept_line = "<C-Down>",
  },

  -- Enable/disable on startup
  enabled = true,

  -- Debug mode (extra logging)
  debug = false,
})
```

## Available Models

| Model | Speed | Quality | Cost |
|-------|-------|---------|------|
| `claude-haiku-4-5-20251001` | Fastest | Good | $1/$5 per MTok |
| `claude-sonnet-4-6` | Fast | Better | $3/$15 per MTok |
| `claude-opus-4-6` | Moderate | Best | $5/$25 per MTok |

For autocomplete, **Haiku** is recommended due to its low latency.

## How It Works

1. **Debouncing**: Waits 300ms after you stop typing before requesting
2. **Context Building**: Gathers current file content, imports, and buffer names
3. **Streaming**: Sends request to Claude API with streaming enabled
4. **Ghost Text**: Renders completions as virtual text using Neovim extmarks

## Security

See [SECURITY.md](SECURITY.md) for information about API key storage and data handling.

## Troubleshooting

### Completions not appearing

1. Check if configured: `:ClaudeCompleteStatus`
2. Test API connection: `:ClaudeCompleteHealthCheck`
3. Enable debug mode in config to see errors

### Slow completions

- Use `claude-haiku-4-5-20251001` (fastest model)
- Reduce `context.max_lines` and `context.max_import_size`
- Increase `debounce_ms` to reduce API calls

### Tab key conflicts

If Tab is used by another plugin, customize the keymap:

```lua
require("claude-complete").setup({
  keymaps = {
    accept = "<C-y>",  -- Use Ctrl+Y instead
  },
})
```

## License

MIT

## Acknowledgments

- [Anthropic](https://www.anthropic.com/) for the Claude API
- Inspired by GitHub Copilot and Codeium
