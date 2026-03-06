-- Anthropic API client for claude-complete.nvim
local M = {}

local config = require("claude-complete.config")

-- Active job ID for cancellation
M.active_job = nil

-- API endpoint
local API_URL = "https://api.anthropic.com/v1/messages"
local API_VERSION = "2023-06-01"

-- Build the prompt for code completion
local function build_prompt(context)
  -- Check if there's content after cursor
  local has_after = context.after_cursor and context.after_cursor ~= ""

  local file_content
  if has_after then
    file_content = string.format(
      "%s<|CURSOR|>%s",
      context.before_cursor or "",
      context.after_cursor or ""
    )
  else
    file_content = string.format(
      "%s<|CURSOR|>",
      context.before_cursor or ""
    )
  end

  local prompt = string.format(
    [[You are a code completion assistant. Complete the code at the cursor position marked by <|CURSOR|>.

RULES:
- Only output the completion text that should be inserted at <|CURSOR|>, nothing else
- Do not include explanations or markdown
- Do not repeat code that already exists before or after the cursor
- Keep completions concise and relevant
- Match the existing code style
- Consider the code AFTER the cursor when completing - your completion should flow naturally into it
- If no completion is appropriate, output nothing

File: %s
Language: %s

Current file content (<|CURSOR|> marks where completion should be inserted):
```
%s
```

%s

Output only the text to insert at <|CURSOR|>:]],
    context.filename or "unknown",
    context.filetype or "text",
    file_content,
    context.extra_context or ""
  )
  return prompt
end

-- Cancel any active request
function M.cancel()
  if M.active_job then
    vim.fn.jobstop(M.active_job)
    M.active_job = nil
  end
end

-- Make a streaming completion request
-- on_chunk: called with each text chunk as it arrives
-- on_done: called when complete
-- on_error: called on error
function M.complete(context, on_chunk, on_done, on_error)
  -- Cancel any existing request
  M.cancel()

  local cfg = config.get()
  local api_key = cfg.api_key

  if not api_key or api_key == "" then
    if on_error then
      on_error("API key not configured")
    end
    return
  end

  local prompt = build_prompt(context)

  -- Build request body
  local body = vim.json.encode({
    model = cfg.model,
    max_tokens = cfg.max_tokens,
    stream = true,
    messages = {
      {
        role = "user",
        content = prompt,
      },
    },
  })

  -- Escape body for shell
  local escaped_body = body:gsub("'", "'\\''")

  -- Build curl command
  local curl_cmd = string.format(
    [[curl -s -N -X POST '%s' \
      -H 'Content-Type: application/json' \
      -H 'x-api-key: %s' \
      -H 'anthropic-version: %s' \
      -d '%s']],
    API_URL,
    api_key,
    API_VERSION,
    escaped_body
  )

  local accumulated_text = ""
  local buffer = ""

  -- Parse SSE events
  local function parse_sse_line(line)
    if line:match("^data: ") then
      local json_str = line:sub(7)

      -- Handle [DONE] marker
      if json_str == "[DONE]" then
        return nil, true
      end

      local ok, data = pcall(vim.json.decode, json_str)
      if ok and data then
        -- Handle different event types
        if data.type == "content_block_delta" then
          local delta = data.delta
          if delta and delta.type == "text_delta" and delta.text then
            return delta.text, false
          end
        elseif data.type == "message_stop" then
          return nil, true
        elseif data.type == "error" then
          if on_error then
            on_error(data.error and data.error.message or "Unknown API error")
          end
          return nil, true
        end
      end
    end
    return nil, false
  end

  -- Start async curl job
  M.active_job = vim.fn.jobstart(curl_cmd, {
    on_stdout = function(_, data)
      if not data then
        return
      end

      for _, line in ipairs(data) do
        -- Handle buffered partial lines
        if buffer ~= "" then
          line = buffer .. line
          buffer = ""
        end

        -- Skip empty lines
        if line ~= "" then
          local text, done = parse_sse_line(line)

          if text then
            accumulated_text = accumulated_text .. text
            if on_chunk then
              vim.schedule(function()
                on_chunk(text, accumulated_text)
              end)
            end
          end

          if done then
            vim.schedule(function()
              if on_done then
                on_done(accumulated_text)
              end
            end)
            M.active_job = nil
            return
          end
        end
      end
    end,

    on_stderr = function(_, data)
      if data and data[1] ~= "" then
        local err_msg = table.concat(data, "\n")
        if err_msg ~= "" and on_error then
          vim.schedule(function()
            on_error(err_msg)
          end)
        end
      end
    end,

    on_exit = function(_, exit_code)
      M.active_job = nil
      if exit_code ~= 0 and accumulated_text == "" then
        vim.schedule(function()
          if on_error then
            on_error("Request failed with exit code: " .. exit_code)
          end
        end)
      elseif accumulated_text ~= "" then
        vim.schedule(function()
          if on_done then
            on_done(accumulated_text)
          end
        end)
      end
    end,

    stdout_buffered = false,
    stderr_buffered = true,
  })

  return M.active_job
end

-- Check if API is available (simple connectivity test)
function M.health_check(callback)
  local cfg = config.get()
  local api_key = cfg.api_key

  if not api_key or api_key == "" then
    callback(false, "API key not configured")
    return
  end

  -- Make a minimal request to verify API key
  local body = vim.json.encode({
    model = cfg.model,
    max_tokens = 1,
    messages = {
      { role = "user", content = "hi" },
    },
  })

  local escaped_body = body:gsub("'", "'\\''")

  local curl_cmd = string.format(
    [[curl -s -X POST '%s' \
      -H 'Content-Type: application/json' \
      -H 'x-api-key: %s' \
      -H 'anthropic-version: %s' \
      -d '%s']],
    API_URL,
    api_key,
    API_VERSION,
    escaped_body
  )

  vim.fn.jobstart(curl_cmd, {
    on_stdout = function(_, data)
      if data then
        local response = table.concat(data, "")
        local ok, json = pcall(vim.json.decode, response)
        if ok and json then
          if json.error then
            callback(false, json.error.message or "API error")
          else
            callback(true, "API connection successful")
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        callback(false, "Connection failed")
      end
    end,
    stdout_buffered = true,
  })
end

return M
