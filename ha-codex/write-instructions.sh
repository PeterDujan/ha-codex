#!/usr/bin/env bash
set -euo pipefail

PERSIST_DIR="${HA_CODEX_PERSIST_DIR:-/data/ha-codex}"
INSTRUCTIONS_FILE="${HA_CODEX_INSTRUCTIONS_FILE:-${PERSIST_DIR}/AGENTS.md}"
PROFILE_FILE="${HA_CODEX_PROFILE_FILE:-${PERSIST_DIR}/instance-profile.md}"
SCAN_FILE="${HA_CODEX_SCAN_FILE:-${PERSIST_DIR}/instance-scan.json}"

mkdir -p "${PERSIST_DIR}"

cat > "${INSTRUCTIONS_FILE}" <<'EOF'
# HA Codex

## Path Mapping

In this add-on container, paths are mapped differently than HA Core:

- `/homeassistant` = HA config directory, equivalent to `/config` in HA Core
- `/config` does not exist by default; translate user references to `/config/...` into `/homeassistant/...`

## Available Paths

| Path | Description | Access |
|------|-------------|--------|
| `/homeassistant` | HA configuration | read-write |
| `/share` | Shared folder | read-write |
| `/media` | Media files | read-write |
| `/ssl` | SSL certificates | read-only |
| `/backup` | Backups | read-only |
| `/addon_configs` | Add-on configuration folders | read-write |
| `/data/ha-codex` | HA Codex private runtime state | read-write |

## Home Assistant Integration

Use the `homeassistant` MCP server to query entities and call services when MCP is enabled.

## Reading Home Assistant Logs

```bash
ha core logs 2>&1 | tail -100
ha core logs 2>&1 | grep -i keyword
ha core logs 2>&1 | grep -iE "(error|exception)"
tail -100 /homeassistant/home-assistant.log
```

Debug log calls only appear when the logger is set to debug in `configuration.yaml`.
EOF

if [ -f "${PROFILE_FILE}" ]; then
  {
    printf '\n## Local Instance Profile\n\n'
    printf 'Use the local instance profile below as default context for this Home Assistant install.\n'
    printf 'It is specific to this machine, so preserve its structure and working style unless the user asks for a reorganization.\n\n'
    cat "${PROFILE_FILE}"
    if [ -f "${SCAN_FILE}" ]; then
      printf '\nDetailed local discovery is also available at `%s`.\n' "${SCAN_FILE}"
      printf 'Consult it when you need repo boundaries, local add-on paths, remotes, or other broader instance facts without rescanning the whole system.\n'
    fi
    printf '\n'
  } >> "${INSTRUCTIONS_FILE}"
else
  {
    printf '\n## Local Instance Profile\n\n'
    printf 'No local instance profile has been generated yet.\n'
    printf 'If the user asks to initialize or learn this Home Assistant install, tell them they can run `/ha-init` in the terminal before starting `codex`.\n'
    printf 'The `/ha-init` command creates `/data/ha-codex/instance-profile.md` and `/data/ha-codex/instance-scan.json`.\n'
    printf 'Use the profile as default local context in future sessions and consult the scan file for deeper machine-local discovery.\n'
  } >> "${INSTRUCTIONS_FILE}"
fi

echo "[INFO] Wrote ${INSTRUCTIONS_FILE}"
