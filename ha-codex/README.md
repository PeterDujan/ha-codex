# HA Codex

Run [Codex](https://developers.openai.com/codex/cli), OpenAI's coding agent, in your Home Assistant sidebar.

This add-on gives Codex a browser terminal and access to your Home Assistant files, so you can inspect config, edit YAML, and work on local projects from inside Home Assistant.

## Quick Start

```bash
/ha-init
codex
```

## Requirements

- Home Assistant OS or Supervised installation
- ChatGPT account with Codex access, or an OpenAI API key

## Architecture Note

The add-on currently publishes build targets for `amd64`, `aarch64`, `armv7`, `armhf`, and `i386`.

At this time:

- `amd64` and `aarch64` are the tested targets
- `armv7`, `armhf`, and `i386` are untested

The untested targets may work, but they should not be treated as confirmed Codex-supported platforms without local verification.

## What This Add-on Includes

- **Web Terminal**: Access Codex through a browser-based terminal
- **Config Access**: Read and write Home Assistant configuration files
- **hass-mcp Integration**: Direct control of Home Assistant entities and services
- **Session Persistence**: Optional tmux integration across page refreshes
- **Customizable Theme**: Dark or light web terminal themes
- **Architecture Coverage**: Tested on amd64 and aarch64; armv7, armhf, and i386 remain untested build targets
- **Isolated Authentication**: Codex auth is stored under `/data/ha-codex/.codex`

## Install

1. Add the HA-Codex repository to Home Assistant.
2. Install the **HA Codex** add-on.
3. Start the add-on.
4. Open the Web UI from the sidebar.

## First-Time Setup

Do these steps in order the first time you use the add-on.

1. At the terminal prompt, run:

```bash
/ha-init
```

This scans your Home Assistant setup and saves local context for future Codex sessions.

2. Start Codex:

```bash
codex
```

3. Sign in when prompted.

For most users, device login is the easiest option. If you need to start login manually, run:

```bash
codex login --device-auth
```

4. Start using Codex.

Examples:

```bash
codex "List all my automations"
codex "Why is this automation not working?"
codex "Check my configuration for YAML mistakes"
```

## Important: `/ha-init`

`/ha-init` must be run at the terminal prompt.

- run it before starting an interactive `codex` session
- do not type it inside an active `codex` chat session
- if you are already inside `codex`, exit back to the shell first

## Authenticate with Codex

On first launch, start Codex and follow the authentication prompt:

```bash
codex
```

For headless systems, device-code login is usually easiest:

```bash
codex login --device-auth
```

Codex stores credentials in `/data/ha-codex/.codex/auth.json` inside this add-on's private data area. The add-on does not use auth directories from other local add-ons.

## What `/ha-init` Does

When you run `/ha-init`, the add-on:

- Scans your Home Assistant layout
- Learns basic repo and folder structure
- Writes a lightweight profile for future Codex sessions
- Refreshes the generated startup instructions right away

It creates:

- `/data/ha-codex/instance-profile.md` for lightweight startup context
- `/data/ha-codex/instance-scan.json` for deeper local discovery details

If you skip this step, HA Codex still works. It just starts with less local context.

## Home Assistant MCP

When `enable_mcp` is true, the add-on configures Codex with a `homeassistant` MCP server powered by `hass-mcp`.

You can change `enable_mcp` in Home Assistant under `Settings -> Add-ons -> HA Codex -> Configuration`.

The MCP server receives `HA_URL=http://supervisor/core` and the current Supervisor token through environment forwarding. The token is not written into Codex config files.

## Everyday Commands

```bash
/ha-init
codex
codex resume --last
codex login --device-auth
```

## Shell Shortcuts

| Shortcut | Command |
|----------|---------|
| `c` | `codex` |
| `cc` | `codex resume --last` |
| `cr` | `codex resume` |
| `clogin` | `codex login --device-auth` |
| `ha-config` | Navigate to config directory |
| `ha-logs` | View Home Assistant logs |

## Add-on Options

You can change add-on options in Home Assistant:

`Settings -> Add-ons -> HA Codex -> Configuration`

The main options are:

| Option | Description | Default |
|--------|-------------|---------|
| `enable_mcp` | Enable Home Assistant MCP integration | true |
| `terminal_font_size` | Font size (10-24) | 14 |
| `terminal_theme` | dark or light | dark |
| `working_directory` | Start directory | /homeassistant |
| `session_persistence` | Use tmux for persistent sessions | true |
| `auto_update_codex` | Auto-update Codex CLI on startup | false |
| `codex_model` | Default Codex model | gpt-5.4 |
| `codex_reasoning_effort` | Default reasoning effort | high |
| `codex_approval_policy` | Approval behavior | on-request |
| `codex_sandbox_mode` | Codex filesystem sandbox | workspace-write |

## Permission Prompts

By default, HA Codex uses these safer settings:

```yaml
codex_approval_policy: on-request
codex_sandbox_mode: workspace-write
```

With these defaults, Codex may ask before running commands, writing files, using the network, or accessing paths outside its workspace.

For a no-prompt local setup, open Home Assistant, go to `Settings -> Add-ons -> HA Codex -> Configuration`, and set the add-on options to:

```yaml
codex_approval_policy: never
codex_sandbox_mode: danger-full-access
```

Save the configuration, then restart the add-on. This gives Codex much broader access, so only use it on systems where you are comfortable letting Codex act without confirmation.

## File Access

| Path | Description | Access |
|------|-------------|--------|
| `/homeassistant` | HA configuration directory | read-write |
| `/share` | Shared folder | read-write |
| `/media` | Media folder | read-write |
| `/ssl` | SSL certificates | read-only |
| `/backup` | Backups | read-only |
| `/addon_configs` | Add-on config folders | read-write |
| `/data/ha-codex` | HA Codex private runtime state | read-write |

## Persistent Sessions

When `session_persistence` is enabled, the add-on uses tmux session `ha-codex` to keep the terminal alive across browser refreshes.

You can change `session_persistence` in Home Assistant under `Settings -> Add-ons -> HA Codex -> Configuration`.

| Key | Action |
|-----|--------|
| `Ctrl+b d` | Detach from session |
| `Ctrl+b [` | Enter scroll/copy mode |
| Mouse wheel | Scroll history |
| `q` | Exit scroll/copy mode |

## Security

- No API keys are stored in Home Assistant add-on options.
- Codex credentials are stored only in `/data/ha-codex/.codex/auth.json`.
- Supervisor tokens are forwarded through the environment for MCP and are not written into config files.
- `working_directory` is limited to mounted Home Assistant paths and `/data/ha-codex`.
- Codex package versions are pinned at build time. Enable `auto_update_codex` only if you prefer convenience over reproducible startup behavior.

## Troubleshooting

### I cannot sign in

Run:

```bash
codex login --device-auth
```

If you use API-key auth instead, follow the Codex CLI prompt.

### `/ha-init` says it is not recognized

That usually means you typed it inside an active `codex` chat session.

Exit back to the shell, then run:

```bash
/ha-init
```

### Home Assistant MCP is not working

1. Open `Settings -> Add-ons -> HA Codex -> Configuration`.
2. Verify `enable_mcp` is `true`.
3. Restart the add-on after changing the setting.
4. Open Codex and use `/mcp` to confirm the `homeassistant` server is enabled.

### The terminal page does not load

1. Check that the add-on is running.
2. Refresh the Home Assistant page.
3. Review add-on logs for `ttyd` startup errors.

Use the HA-Codex Gitea repository for issues and changes.
