# Security Considerations

## API Key Storage

claude-complete.nvim uses macOS Keychain for secure API key storage. This document explains the security model and best practices.

### How API Keys Are Stored

1. **Environment Variable (Highest Priority)**: If you set `ANTHROPIC_API_KEY` in your environment, the plugin will use it automatically. The key is never written to disk by the plugin.

   ```bash
   # Add to your ~/.bashrc, ~/.zshrc, or equivalent
   export ANTHROPIC_API_KEY="your-api-key-here"
   ```

2. **macOS Keychain (Recommended)**: When you run `:ClaudeCompleteSetup`, the API key is securely stored in macOS Keychain under:
   - **Service**: `claude-complete-nvim`
   - **Account**: `anthropic-api-key`

   You can view or manage this entry in the Keychain Access app or via:
   ```bash
   security find-generic-password -s "claude-complete-nvim" -a "anthropic-api-key"
   ```

### Security Measures

- **Encrypted Storage**: Keychain encrypts credentials using your login password
- **OS-Level Protection**: Access is controlled by macOS security policies
- **No Plain Text Files**: API keys are never stored in plain text on disk
- **No Logging**: API keys are never logged or displayed in notifications
- **Local Storage Only**: Keys are stored locally and only transmitted to Anthropic's API

### Keychain Benefits

- **Encrypted at rest**: Protected by your macOS login keychain
- **Access control**: macOS prompts if unauthorized apps try to access
- **Survives config changes**: Separate from your Neovim configuration
- **Standard practice**: Same approach used by AWS CLI, 1Password CLI, etc.

### Best Practices

1. **Use Keychain or Environment Variables**: Both are secure options

2. **Use Separate API Keys**: Create a dedicated API key for this plugin in the Anthropic Console, so you can revoke it independently if needed

3. **Monitor Usage**: Regularly check your Anthropic API usage dashboard for unexpected activity

4. **Rotate Keys**: Periodically rotate your API keys, especially if you suspect compromise

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
