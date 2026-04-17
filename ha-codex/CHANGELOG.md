# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-04-16

### Added
- First public HA Codex release for running OpenAI Codex inside Home Assistant through a browser terminal.
- Home Assistant MCP integration through `hass-mcp`.
- Local instance bootstrap with `/ha-init` to generate saved context for future Codex sessions.
- tmux-backed session persistence, configurable terminal options, and isolated Codex state under `/data/ha-codex`.

### Changed
- Simplified the documentation for first-time users and made the install and first-run flow clearer.
- Standardized user-facing setup instructions on `/ha-init`.
- Clarified that `amd64` and `aarch64` are the tested targets, while `armv7`, `armhf`, and `i386` remain untested build targets.

### Removed
- Removed the Playwright companion add-on and its related MCP wiring from this repository.

### Security
- Pinned core build dependencies and the Home Assistant CLI download to explicit versions.
- Kept Codex credentials isolated under `/data/ha-codex/.codex`.
- Forwarded the Supervisor token through the environment for MCP instead of writing it into Codex config files.
