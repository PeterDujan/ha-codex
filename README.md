# HA-Codex Add-ons

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Run OpenAI Codex inside Home Assistant through a browser terminal.

## Warning

This repository is not officially supported. Use it carefully and test changes in your own environment.

## Attribution

This repository is a fork of [robsonfelix-hass-addons](https://github.com/robsonfelix/robsonfelix-hass-addons). Credit to [Robson Felix](https://github.com/robsonfelix) for the original add-on work this repository builds on.

This repository continues to use the same MIT license.

## Included Add-on

| Add-on | Description |
|--------|-------------|
| [HA Codex](ha-codex/) | Codex CLI with a web terminal, Home Assistant MCP, and isolated persistent auth |

## What It Does

- Opens Codex in the Home Assistant sidebar
- Lets Codex read and edit your Home Assistant files
- Can connect Codex to Home Assistant through MCP

## Install In Home Assistant

Add this repository URL to the Home Assistant add-on store:

```text
https://github.com/PeterDujan/ha-codex
```

Then install **HA Codex** from the add-on store.

## First-Time Setup

1. Start the add-on.
2. Open the Web UI.
3. At the terminal prompt, run:

```bash
/ha-init
```

4. Then start Codex:

```bash
codex
```

5. Sign in when prompted. For most users, device login is the easiest option.

`/ha-init` must be run at the shell prompt, not inside an active `codex` chat session.

For full setup, configuration, and troubleshooting, see [ha-codex/README.md](ha-codex/README.md).

## License

MIT License
