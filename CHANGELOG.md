# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Automated service installation** - `install-service.sh` script for one-command setup on macOS and Linux
- **Service uninstaller** - `uninstall-service.sh` for clean removal
- **Array content format support** - Handles both string and array-based message content, fixing `[object Object]` serialization issues (from PR #27)
- **System prompt support** - Proper handling via `--append-system-prompt` CLI flag instead of embedding in prompts (from PR #16)
- **Streaming usage data** - Token usage information now included in final streaming chunks (from PR #16)
- **Claude 4.5/4.6 model support** - Updated model mappings for latest Claude versions (from PR #10, #16)
- **Environment variable support** - `CLAUDE_DANGEROUSLY_SKIP_PERMISSIONS` for service/automated environments (from PR #13, #16)
- **Flexible model name normalization** - Supports any provider prefix (claude-max/, claude-code-cli/, etc.) (from PR #24)

### Fixed
- **E2BIG error prevention** - Prompts now passed via stdin instead of CLI arguments, preventing "argument list too long" errors with large prompts (from PR #12, #16)
- **Undefined model handling** - Gracefully handles undefined/null model names without crashing (from PR #24)
- **Content extraction** - Properly extracts text from array-formatted content parts (from PR #27)

### Changed
- System messages no longer embedded as `<system>` tags in prompts - now use proper `--append-system-prompt` flag
- Model extraction now handles any provider prefix pattern, not just hardcoded `claude-code-cli/`
- Improved error handling for edge cases in content serialization

## [1.0.0] - 2025-01-XX

### Added
- Initial release
- OpenAI-compatible API server wrapping Claude Code CLI
- Streaming and non-streaming chat completions
- Session management
- Basic model support (Opus, Sonnet, Haiku)
- Health check and models endpoints
- Security via spawn() instead of shell execution

---

## Credits

This release incorporates improvements from multiple community PRs:
- PR #27 by @darrenwadley-ui - Array content handling
- PR #24 by @sven-ea-assistant - Model name normalization
- PR #16 by @smartchainark - System prompts, streaming usage, stdin delivery
- PR #12 by @kevinfealey - stdin prompt delivery
- PR #13 by @kevinfealey - Permission skip env var
- PR #10 by @jamshehan - Claude 4.5/4.6 model support

Thank you to all contributors at https://github.com/atalovesyou/claude-max-api-proxy!
