#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE=/data/options.json
PERSIST_DIR=/data/ha-codex
CODEX_HOME_DIR="${PERSIST_DIR}/.codex"
SQLITE_DIR="${PERSIST_DIR}/sqlite"
INSTRUCTIONS_FILE="${PERSIST_DIR}/AGENTS.md"
PROFILE_FILE="${PERSIST_DIR}/instance-profile.md"
SCAN_FILE="${PERSIST_DIR}/instance-scan.json"

export CODEX_HOME="${CODEX_HOME_DIR}"
export HA_URL="http://supervisor/core"
export HA_TOKEN="${SUPERVISOR_TOKEN:-}"

option() {
  local key="$1"
  local default="$2"
  jq -r --arg key "$key" --arg default "$default" '.[$key] // $default' "$CONFIG_FILE"
}

toml_string() {
  jq -Rn -r --arg value "$1" '$value | @json'
}

valid_workdir() {
  case "$1" in
    /homeassistant|/homeassistant/*|/share|/share/*|/media|/media/*|/ssl|/ssl/*|/backup|/backup/*|/addon_configs|/addon_configs/*|/data/ha-codex|/data/ha-codex/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

mkdir -p "${CODEX_HOME_DIR}" "${SQLITE_DIR}" "${PERSIST_DIR}/tmp" /root/.config
chmod 700 "${PERSIST_DIR}" "${CODEX_HOME_DIR}" "${SQLITE_DIR}" || true

if [ ! -L /root/.codex ]; then
  rm -rf /root/.codex
  ln -s "${CODEX_HOME_DIR}" /root/.codex
fi

HA_CODEX_PERSIST_DIR="${PERSIST_DIR}" \
HA_CODEX_INSTRUCTIONS_FILE="${INSTRUCTIONS_FILE}" \
HA_CODEX_PROFILE_FILE="${PROFILE_FILE}" \
HA_CODEX_SCAN_FILE="${SCAN_FILE}" \
  /usr/local/bin/ha-codex-write-instructions

FONT_SIZE="$(option terminal_font_size 14)"
THEME="$(option terminal_theme dark)"
SESSION_PERSIST="$(option session_persistence true)"
ENABLE_MCP="$(option enable_mcp true)"
AUTO_UPDATE="$(option auto_update_codex false)"
MODEL="$(option codex_model gpt-5.4)"
REASONING="$(option codex_reasoning_effort high)"
APPROVAL="$(option codex_approval_policy on-request)"
SANDBOX="$(option codex_sandbox_mode workspace-write)"
WORKDIR="$(option working_directory /homeassistant)"

case "${THEME}" in dark|light) ;; *) THEME=dark ;; esac
case "${SESSION_PERSIST}" in true|false) ;; *) SESSION_PERSIST=true ;; esac
case "${ENABLE_MCP}" in true|false) ;; *) ENABLE_MCP=true ;; esac
case "${AUTO_UPDATE}" in true|false) ;; *) AUTO_UPDATE=true ;; esac
case "${REASONING}" in minimal|low|medium|high|xhigh) ;; *) REASONING=high ;; esac
case "${APPROVAL}" in untrusted|on-request|never) ;; *) APPROVAL=on-request ;; esac
case "${SANDBOX}" in read-only|workspace-write|danger-full-access) ;; *) SANDBOX=workspace-write ;; esac

if ! printf '%s' "${FONT_SIZE}" | grep -Eq '^[0-9]+$'; then
  FONT_SIZE=14
fi
if [ "${FONT_SIZE}" -lt 10 ] || [ "${FONT_SIZE}" -gt 24 ]; then
  FONT_SIZE=14
fi

if ! valid_workdir "${WORKDIR}" || [ ! -d "${WORKDIR}" ]; then
  echo "[WARN] Invalid or missing working_directory '${WORKDIR}', using /homeassistant"
  WORKDIR=/homeassistant
fi

if [ -z "${MODEL}" ]; then
  MODEL=gpt-5.4
fi

if [ "${AUTO_UPDATE}" = "true" ]; then
  echo "[INFO] Checking for Codex CLI updates..."
  npm i -g @openai/codex@latest 2>/dev/null || echo "[WARN] Codex update check failed, continuing..."
fi

cat > "${CODEX_HOME_DIR}/config.toml" << EOF
model = $(toml_string "${MODEL}")
model_reasoning_effort = $(toml_string "${REASONING}")
approval_policy = $(toml_string "${APPROVAL}")
sandbox_mode = $(toml_string "${SANDBOX}")
cli_auth_credentials_store = "file"
check_for_update_on_startup = false
sqlite_home = $(toml_string "${SQLITE_DIR}")
web_search = "cached"

[sandbox_workspace_write]
writable_roots = ["/homeassistant", "/share", "/media", "/addon_configs", "/data/ha-codex"]
network_access = true

[projects."/homeassistant"]
trust_level = "trusted"
EOF

if [ "${ENABLE_MCP}" = "true" ]; then
  cat >> "${CODEX_HOME_DIR}/config.toml" << EOF
[mcp_servers.homeassistant]
command = "hass-mcp"
env_vars = ["HA_TOKEN", "HA_URL"]
startup_timeout_sec = 30
tool_timeout_sec = 120
EOF
fi

echo "[INFO] Codex home: ${CODEX_HOME_DIR}"
echo "[INFO] Codex model: ${MODEL} (${REASONING})"
echo "[INFO] Home Assistant MCP: ${ENABLE_MCP}"

if [ "${THEME}" = "dark" ]; then
  COLORS='background=#1e1e2e,foreground=#cdd6f4,cursor=#f5e0dc'
else
  COLORS='background=#eff1f5,foreground=#4c4f69,cursor=#dc8a78'
fi

if [ "${SESSION_PERSIST}" = "true" ]; then
  SHELL_CMD=(tmux new-session -A -s ha-codex)
else
  SHELL_CMD=(bash --login)
fi

cd "${WORKDIR}"
exec ttyd --port 7681 --writable --ping-interval 30 --max-clients 5 \
  -t "fontSize=${FONT_SIZE}" \
  -t fontFamily=Monaco,Consolas,monospace \
  -t scrollback=20000 \
  -t "theme=${COLORS}" \
  "${SHELL_CMD[@]}"
