# Security Considerations

## API Key Storage

claude-complete.nvim stores your Anthropic API key in a configuration file for convenience. This document explains the security implications and best practices.

### How API Keys Are Stored

1. **Environment Variable (Recommended)**: If you set `ANTHROPIC_API_KEY` in your environment, the plugin will use it automatically. The key is never written to disk by the plugin.

   ```bash
   # Add to your ~/.bashrc, ~/.zshrc, or equivalent
   export ANTHROPIC_API_KEY="your-api-key-here"
   ```

2. **Config File**: When you run `:ClaudeCompleteSetup`, the API key is saved to:
   ```
   ~/.config/nvim/claude-complete.json
   ```

### Security Measures

- **File Permissions**: The config file is created with `chmod 600` (owner read/write only)
- **No Logging**: API keys are never logged or displayed in notifications
- **Local Storage Only**: Keys are stored locally and only transmitted to Anthropic's API

### Risks

- **Plain Text Storage**: The config file stores the API key in plain text JSON
- **File System Access**: Anyone with access to your Neovim config directory can read the key
- **Backup Systems**: The config file may be included in system backups
- **Version Control**: Be careful not to commit the config file to git

### Best Practices

1. **Use Environment Variables**: This is the most secure option as the key stays in memory only

2. **Restrict File Permissions**: Ensure your config directory has appropriate permissions
   ```bash
   chmod 700 ~/.config/nvim
   chmod 600 ~/.config/nvim/claude-complete.json
   ```

3. **Add to .gitignore**: If your nvim config is version controlled
   ```gitignore
   claude-complete.json
   ```

4. **Use Separate API Keys**: Create a dedicated API key for this plugin in the Anthropic Console, so you can revoke it independently if needed

5. **Monitor Usage**: Regularly check your Anthropic API usage dashboard for unexpected activity

6. **Rotate Keys**: Periodically rotate your API keys, especially if you suspect compromise

### If Your Key Is Compromised

1. Immediately revoke the key in the [Anthropic Console](https://console.anthropic.com/)
2. Generate a new API key
3. Update your local configuration with the new key
4. Review your API usage logs for unauthorized access

### Data Transmission

When you use claude-complete.nvim:

- **Sent to Anthropic**: Code context from your current file and imported files
- **Not Sent**: File paths on your system (only relative names), system information, other buffer contents not relevant to completion

All data is transmitted over HTTPS to Anthropic's API endpoints.

### Reporting Security Issues

If you discover a security vulnerability in this plugin, please report it responsibly by opening a private security advisory on the GitHub repository.
