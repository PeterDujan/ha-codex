#!/usr/bin/env bash
set -euo pipefail

PERSIST_DIR="${HA_CODEX_PERSIST_DIR:-/data/ha-codex}"
PROFILE_FILE="${PERSIST_DIR}/instance-profile.md"
SCAN_FILE="${PERSIST_DIR}/instance-scan.json"
INSTRUCTIONS_FILE="${HA_CODEX_INSTRUCTIONS_FILE:-${PERSIST_DIR}/AGENTS.md}"
HOMEASSISTANT_DIR="${HA_CODEX_HOMEASSISTANT_DIR:-/homeassistant}"
CONFIG_FILE="${HA_CODEX_CONFIG_FILE:-/homeassistant/configuration.yaml}"
AUTOMATIONS_FILE="${HA_CODEX_AUTOMATIONS_FILE:-/homeassistant/automations.yaml}"
SCRIPTS_FILE="${HA_CODEX_SCRIPTS_FILE:-/homeassistant/scripts.yaml}"
CUSTOM_COMPONENTS_DIR="${HA_CODEX_CUSTOM_COMPONENTS_DIR:-${HOMEASSISTANT_DIR}/custom_components}"
THEMES_DIR="${HA_CODEX_THEMES_DIR:-${HOMEASSISTANT_DIR}/themes}"
PACKAGES_DIR="${HA_CODEX_PACKAGES_DIR:-${HOMEASSISTANT_DIR}/packages}"
ESPHOME_DIR="${HA_CODEX_ESPHOME_DIR:-${HOMEASSISTANT_DIR}/esphome}"
WWW_DIR="${HA_CODEX_WWW_DIR:-${HOMEASSISTANT_DIR}/www}"
ADDONS_LOCAL_DIR="${HA_CODEX_ADDONS_LOCAL_DIR:-${HOMEASSISTANT_DIR}/addons/local}"
WWW_LIF_ADDONS_DIR="${HA_CODEX_WWW_LIF_ADDONS_DIR:-${WWW_DIR}/lif-addons}"
WRITE_INSTRUCTIONS_SCRIPT="${HA_CODEX_WRITE_INSTRUCTIONS_SCRIPT:-/usr/local/bin/ha-codex-write-instructions}"

mkdir -p "${PERSIST_DIR}"

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "[ERROR] ${CONFIG_FILE} not found"
  exit 1
fi

count_nonempty() {
  awk 'NF { count++ } END { print count + 0 }' "$1"
}

list_child_dirs() {
  if [ -d "$1" ]; then
    find "$1" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
  fi
}

count_child_dirs() {
  if [ -d "$1" ]; then
    find "$1" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '
  else
    printf '0\n'
  fi
}

count_root_yaml_files() {
  if [ -d "$1" ]; then
    find "$1" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) | wc -l | tr -d ' '
  else
    printf '0\n'
  fi
}

list_root_yaml_files() {
  if [ -d "$1" ]; then
    find "$1" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) -printf '%f\n' | sort
  fi
}

json_array_from_lines() {
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1" | sed '/^$/d' | jq -Rn '[inputs | select(length > 0)]'
  else
    printf '[]\n'
  fi
}

sanitize_profile_lines() {
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1" | awk '
      {
        # Keep profile-facing text plain and low-risk. Raw values stay in instance-scan.json.
        gsub(/[^[:alnum:] .,:\/_@+\-]/, "_")
        sub(/^[-_[:space:]]+/, "")
        if (length($0) > 160) {
          $0 = substr($0, 1, 157) "..."
        }
        if (length($0) > 0) {
          print
        }
      }
    '
  fi
}

preview_lines() {
  if [ -z "${1:-}" ]; then
    printf 'none\n'
    return
  fi

  sanitize_profile_lines "$1" | awk '
    NR == 1 { out = $0 }
    NR > 1 && NR <= 5 { out = out ", " $0 }
    END {
      if (NR == 0) {
        print "none"
      } else if (NR > 5) {
        print out ", ..."
      } else {
        print out
      }
    }
  '
}

dir_status() {
  if [ -d "$1" ]; then
    printf 'present'
  else
    printf 'absent'
  fi
}

has_top_level_key() {
  local key="$1"
  awk -v key="$key" '
    /^[[:space:]]*#/ { next }
    /^[^[:space:]#][^:]*:/ {
      current = $0
      sub(/:.*/, "", current)
      if (current == key) {
        found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' "$CONFIG_FILE"
}

top_level_keys() {
  awk '
    /^[[:space:]]*#/ { next }
    /^[^[:space:]#][^:]*:/ {
      key = $0
      sub(/:.*/, "", key)
      print key
    }
  ' "$1"
}

include_lines() {
  awk '
    /^[[:space:]]*#/ { next }
    match($0, /^([^[:space:]#][^:]*):[[:space:]]*(!include[^[:space:]]*)[[:space:]]*(.+)$/, parts) {
      printf("%s\t%s\t%s\n", parts[1], parts[3], parts[2])
    }
  ' "$1"
}

list_dashboard_files() {
  if [ -d "$HOMEASSISTANT_DIR" ]; then
    find "$HOMEASSISTANT_DIR" -maxdepth 1 -type f \( -name '*dashboard*.yaml' -o -name 'ui-lovelace*.yaml' \) -printf '%f\n' | sort
  fi
}

list_addon_manifests() {
  if [ -d "$1" ]; then
    find "$1" -maxdepth 3 -type f -name config.yaml | sed "s#^$1/##" | sort
  fi
}

list_git_roots() {
  if [ -d "$HOMEASSISTANT_DIR" ]; then
    if [ -d "${HOMEASSISTANT_DIR}/.git" ]; then
      printf '%s\n' "${HOMEASSISTANT_DIR}"
    fi
    find "$HOMEASSISTANT_DIR" \
      -mindepth 1 \
      \( -path "${HOMEASSISTANT_DIR}/.*" -o -path '*/node_modules/*' -o -path '*/.venv/*' -o -path '*/venv/*' -o -path '*/__pycache__/*' \) -prune -o \
      -type d -name .git -print | sed 's#/.git$##' | sort -u
  fi
}

remote_host() {
  case "$1" in
    http://*|https://*)
      printf '%s\n' "$1" | sed -E 's#^[a-z]+://([^/@]+@)?([^/:]+)(:[0-9]+)?/.*#\2\3#'
      ;;
    git@*:* )
      printf '%s\n' "$1" | sed -E 's#^git@([^:]+):.*#\1#'
      ;;
    ssh://* )
      printf '%s\n' "$1" | sed -E 's#^ssh://([^/@]+@)?([^/:]+)(:[0-9]+)?/.*#\2\3#'
      ;;
    * )
      printf '\n'
      ;;
  esac
}

sanitize_remote_url() {
  case "$1" in
    http://*|https://*)
      printf '%s\n' "$1" | sed -E 's#^([a-z]+://)[^/@]+@#\1#'
      ;;
    ssh://*)
      printf '%s\n' "$1" | sed -E 's#^(ssh://)[^/@]+@#\1#'
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

is_self_hosted_host() {
  case "$1" in
    ""|github.com|gitlab.com|bitbucket.org)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

bool_word() {
  if [ "$1" = "true" ]; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}

markdown_include_map() {
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1" | while IFS="$(printf '\t')" read -r key target directive; do
      key="$(sanitize_profile_lines "${key}")"
      target="$(sanitize_profile_lines "${target}")"
      directive="$(sanitize_profile_lines "${directive}")"
      [ -n "${key}" ] || continue
      printf -- '- `%s` -> `%s` (%s)\n' "${key}" "${target}" "${directive}"
    done
  else
    printf '%s\n' "- No top-level \`!include\` directives detected in \`configuration.yaml\`."
  fi
}

join_markdown_list() {
  if [ -n "${1:-}" ]; then
    sanitize_profile_lines "$1" | awk '{ printf("- `%s`\n", $0) }'
  else
    printf '%s\n' "- none"
  fi
}

CONFIG_LINES="$(wc -l < "${CONFIG_FILE}" | tr -d ' ')"
TOP_LEVEL_KEYS="$(top_level_keys "${CONFIG_FILE}")"
TOP_LEVEL_KEYS_JSON="$(json_array_from_lines "${TOP_LEVEL_KEYS}")"
TOP_LEVEL_KEY_COUNT="$(printf '%s' "${TOP_LEVEL_KEYS_JSON}" | jq 'length')"
INCLUDE_COUNT="$(awk '/^[[:space:]]*#/ { next } /^[^[:space:]#][^:]*:[[:space:]]*!include/ { count++ } END { print count + 0 }' "${CONFIG_FILE}")"
INCLUDE_DIR_COUNT="$(grep -c '^[^[:space:]#][^:]*:[[:space:]]*!include_dir' "${CONFIG_FILE}" || true)"
DIRECT_ROOT_COUNT=$((TOP_LEVEL_KEY_COUNT - INCLUDE_COUNT))
DASHBOARD_FILES="$(list_dashboard_files)"
DASHBOARD_FILES_JSON="$(json_array_from_lines "${DASHBOARD_FILES}")"
DASHBOARD_FILE_COUNT="$(printf '%s' "${DASHBOARD_FILES_JSON}" | jq 'length')"
CUSTOM_COMPONENT_COUNT="$(count_child_dirs "${CUSTOM_COMPONENTS_DIR}")"
CUSTOM_COMPONENT_NAMES="$(list_child_dirs "${CUSTOM_COMPONENTS_DIR}")"
CUSTOM_COMPONENT_NAMES_JSON="$(json_array_from_lines "${CUSTOM_COMPONENT_NAMES}")"
THEME_FILE_COUNT="$(count_root_yaml_files "${THEMES_DIR}")"
THEME_FILES="$(list_root_yaml_files "${THEMES_DIR}")"
THEME_FILES_JSON="$(json_array_from_lines "${THEME_FILES}")"
PACKAGE_FILE_COUNT="$(count_root_yaml_files "${PACKAGES_DIR}")"
PACKAGE_FILES="$(list_root_yaml_files "${PACKAGES_DIR}")"
PACKAGE_FILES_JSON="$(json_array_from_lines "${PACKAGE_FILES}")"
ESPHOME_FILE_COUNT="$(count_root_yaml_files "${ESPHOME_DIR}")"
ESPHOME_FILES="$(list_root_yaml_files "${ESPHOME_DIR}")"
ESPHOME_FILES_JSON="$(json_array_from_lines "${ESPHOME_FILES}")"
WWW_CHILD_DIR_COUNT="$(count_child_dirs "${WWW_DIR}")"
WWW_CHILD_DIRS="$(list_child_dirs "${WWW_DIR}")"
WWW_CHILD_DIRS_JSON="$(json_array_from_lines "${WWW_CHILD_DIRS}")"
LOCAL_ADDON_MANIFESTS="$(list_addon_manifests "${ADDONS_LOCAL_DIR}")"
LOCAL_ADDON_MANIFESTS_JSON="$(json_array_from_lines "${LOCAL_ADDON_MANIFESTS}")"
LOCAL_ADDON_COUNT="$(printf '%s' "${LOCAL_ADDON_MANIFESTS_JSON}" | jq 'length')"
WWW_LIF_ADDON_DIRS="$(list_child_dirs "${WWW_LIF_ADDONS_DIR}")"
WWW_LIF_ADDON_DIRS_JSON="$(json_array_from_lines "${WWW_LIF_ADDON_DIRS}")"
WWW_LIF_ADDON_COUNT="$(printf '%s' "${WWW_LIF_ADDON_DIRS_JSON}" | jq 'length')"
INCLUDE_LINES="$(include_lines "${CONFIG_FILE}")"

if [ -n "${INCLUDE_LINES}" ]; then
  INCLUDE_JSON="$(printf '%s\n' "${INCLUDE_LINES}" | jq -Rn '[inputs | select(length > 0) | split("\t") | {key: .[0], target: .[1], directive: .[2]}]')"
else
  INCLUDE_JSON='[]'
fi

API_STATUS="not checked"
if command -v curl >/dev/null 2>&1 && [ -n "${HA_URL:-}" ] && [ -n "${HA_TOKEN:-}" ]; then
  if curl -fsS --max-time 5 -H "Authorization: Bearer ${HA_TOKEN}" "${HA_URL}/api/config" >/dev/null 2>&1; then
    API_STATUS="ok"
  else
    API_STATUS="failed"
  fi
elif [ -n "${HA_URL:-}" ] && [ -n "${HA_TOKEN:-}" ]; then
  API_STATUS="env present, curl unavailable"
fi

if command -v hass-mcp >/dev/null 2>&1; then
  MCP_BINARY_STATUS="available"
else
  MCP_BINARY_STATUS="missing"
fi

if [ "${API_STATUS}" = "ok" ] && [ "${MCP_BINARY_STATUS}" = "available" ]; then
  MCP_SUMMARY="Home Assistant API access is working and the \`hass-mcp\` binary is available."
elif [ "${API_STATUS}" = "ok" ]; then
  MCP_SUMMARY="Home Assistant API access is working, but the \`hass-mcp\` binary was not found on PATH."
elif [ "${MCP_BINARY_STATUS}" = "available" ]; then
  MCP_SUMMARY="The \`hass-mcp\` binary is available, but Home Assistant API access was not verified during \`/init\`."
else
  MCP_SUMMARY="Home Assistant API access and MCP readiness were not fully verified during \`/init\`."
fi

HAS_LOVELACE=false
has_top_level_key lovelace && HAS_LOVELACE=true
HAS_SHELL_COMMAND=false
has_top_level_key shell_command && HAS_SHELL_COMMAND=true
HAS_COMMAND_LINE=false
has_top_level_key command_line && HAS_COMMAND_LINE=true
HAS_TEMPLATE=false
has_top_level_key template && HAS_TEMPLATE=true
HAS_SENSOR=false
has_top_level_key sensor && HAS_SENSOR=true
HAS_REST_COMMAND=false
has_top_level_key rest_command && HAS_REST_COMMAND=true

GIT_REPO_ROOTS="$(list_git_roots)"
if [ -n "${GIT_REPO_ROOTS}" ]; then
  REPO_JSON="$(
    while IFS= read -r repo; do
      [ -n "${repo}" ] || continue
      if [ "${repo}" = "${HOMEASSISTANT_DIR}" ]; then
        repo_path='.'
      else
        repo_path="${repo#${HOMEASSISTANT_DIR}/}"
      fi
      origin_url_raw="$(git -C "${repo}" config --get remote.origin.url 2>/dev/null || true)"
      origin_url="$(sanitize_remote_url "${origin_url_raw}")"
      remote_host_value="$(remote_host "${origin_url}")"
      self_hosted=false
      if is_self_hosted_host "${remote_host_value}"; then
        self_hosted=true
      fi
      jq -cn \
        --arg path "${repo_path}" \
        --arg origin_url "${origin_url}" \
        --arg remote_host "${remote_host_value}" \
        --argjson self_hosted "${self_hosted}" \
        '{
          path: $path,
          origin_url: (if $origin_url == "" then null else $origin_url end),
          remote_host: (if $remote_host == "" then null else $remote_host end),
          self_hosted_remote: $self_hosted
        }'
    done <<EOF
${GIT_REPO_ROOTS}
EOF
  )"
  REPO_JSON="$(printf '%s\n' "${REPO_JSON}" | jq -s '.')"
else
  REPO_JSON='[]'
fi

REPO_COUNT="$(printf '%s' "${REPO_JSON}" | jq 'length')"
SELF_HOSTED_REPO_COUNT="$(printf '%s' "${REPO_JSON}" | jq '[.[] | select(.self_hosted_remote == true)] | length')"

if [ "${INCLUDE_COUNT}" -ge 4 ] || [ "${INCLUDE_DIR_COUNT}" -ge 2 ]; then
  STRUCTURE_STYLE="modular"
  STRUCTURE_SUMMARY="This Home Assistant setup uses a modular structure with multiple include files or folders."
  ROOT_GUIDANCE="Keep \`configuration.yaml\` tidy. Prefer extending the existing include pattern instead of adding new sections at the root when a matching pattern already exists."
elif [ "${INCLUDE_COUNT}" -ge 1 ]; then
  STRUCTURE_STYLE="mixed"
  STRUCTURE_SUMMARY="This Home Assistant setup mixes root-level configuration with a smaller number of include files."
  ROOT_GUIDANCE="Preserve the current split. Add new configuration where similar configuration already lives instead of forcing a reorganization."
else
  STRUCTURE_STYLE="root-centric"
  STRUCTURE_SUMMARY="This Home Assistant setup is mostly managed directly from \`configuration.yaml\`."
  ROOT_GUIDANCE="Match the existing root-centric style unless the user explicitly asks for a cleanup or refactor."
fi

AUTOMATION_STATUS="\`automations.yaml\` not found"
if [ -f "${AUTOMATIONS_FILE}" ]; then
  AUTOMATION_STATUS="\`automations.yaml\` present with $(count_nonempty "${AUTOMATIONS_FILE}") non-empty lines"
fi

SCRIPT_STATUS="\`scripts.yaml\` not found"
if [ -f "${SCRIPTS_FILE}" ]; then
  SCRIPT_STATUS="\`scripts.yaml\` present with $(count_nonempty "${SCRIPTS_FILE}") non-empty lines"
fi

cat > "${SCAN_FILE}" <<EOF
$(jq -n \
  --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg homeassistant_dir "${HOMEASSISTANT_DIR}" \
  --arg profile_file "${PROFILE_FILE}" \
  --arg config_file "${CONFIG_FILE}" \
  --arg automations_file "${AUTOMATIONS_FILE}" \
  --arg scripts_file "${SCRIPTS_FILE}" \
  --arg structure_style "${STRUCTURE_STYLE}" \
  --arg structure_summary "${STRUCTURE_SUMMARY}" \
  --arg root_guidance "${ROOT_GUIDANCE}" \
  --arg api_status "${API_STATUS}" \
  --arg mcp_binary_status "${MCP_BINARY_STATUS}" \
  --arg mcp_summary "${MCP_SUMMARY}" \
  --argjson config_lines "${CONFIG_LINES}" \
  --argjson top_level_key_count "${TOP_LEVEL_KEY_COUNT}" \
  --argjson include_count "${INCLUDE_COUNT}" \
  --argjson include_dir_count "${INCLUDE_DIR_COUNT}" \
  --argjson direct_root_count "${DIRECT_ROOT_COUNT}" \
  --argjson dashboard_file_count "${DASHBOARD_FILE_COUNT}" \
  --argjson custom_component_count "${CUSTOM_COMPONENT_COUNT}" \
  --argjson theme_file_count "${THEME_FILE_COUNT}" \
  --argjson package_file_count "${PACKAGE_FILE_COUNT}" \
  --argjson esphome_file_count "${ESPHOME_FILE_COUNT}" \
  --argjson www_child_dir_count "${WWW_CHILD_DIR_COUNT}" \
  --argjson local_addon_count "${LOCAL_ADDON_COUNT}" \
  --argjson www_lif_addon_count "${WWW_LIF_ADDON_COUNT}" \
  --argjson repo_count "${REPO_COUNT}" \
  --argjson self_hosted_repo_count "${SELF_HOSTED_REPO_COUNT}" \
  --argjson has_lovelace "${HAS_LOVELACE}" \
  --argjson has_shell_command "${HAS_SHELL_COMMAND}" \
  --argjson has_command_line "${HAS_COMMAND_LINE}" \
  --argjson has_template "${HAS_TEMPLATE}" \
  --argjson has_sensor "${HAS_SENSOR}" \
  --argjson has_rest_command "${HAS_REST_COMMAND}" \
  --argjson top_level_keys "${TOP_LEVEL_KEYS_JSON}" \
  --argjson include_patterns "${INCLUDE_JSON}" \
  --argjson dashboards "${DASHBOARD_FILES_JSON}" \
  --argjson custom_components "${CUSTOM_COMPONENT_NAMES_JSON}" \
  --argjson theme_files "${THEME_FILES_JSON}" \
  --argjson package_files "${PACKAGE_FILES_JSON}" \
  --argjson esphome_files "${ESPHOME_FILES_JSON}" \
  --argjson www_child_dirs "${WWW_CHILD_DIRS_JSON}" \
  --argjson local_addon_manifests "${LOCAL_ADDON_MANIFESTS_JSON}" \
  --argjson www_lif_addon_dirs "${WWW_LIF_ADDON_DIRS_JSON}" \
  --argjson repos "${REPO_JSON}" \
  '{
    generated_at: $generated_at,
    homeassistant_dir: $homeassistant_dir,
    files: {
      profile_file: $profile_file,
      config_file: $config_file,
      automations_file: $automations_file,
      scripts_file: $scripts_file
    },
    config: {
      structure_style: $structure_style,
      structure_summary: $structure_summary,
      root_guidance: $root_guidance,
      configuration_yaml: {
        line_count: $config_lines,
        top_level_key_count: $top_level_key_count,
        top_level_keys: $top_level_keys,
        include_count: $include_count,
        include_dir_count: $include_dir_count,
        direct_root_count: $direct_root_count,
        include_patterns: $include_patterns
      },
      feature_flags: {
        lovelace: $has_lovelace,
        shell_command: $has_shell_command,
        command_line: $has_command_line,
        template: $has_template,
        sensor: $has_sensor,
        rest_command: $has_rest_command
      }
    },
    environment: {
      api_check: $api_status,
      hass_mcp_on_path: $mcp_binary_status,
      mcp_summary: $mcp_summary
    },
    work_areas: {
      dashboards: {
        root_yaml_file_count: $dashboard_file_count,
        files: $dashboards
      },
      custom_components: {
        present: ($custom_component_count > 0),
        count: $custom_component_count,
        names: $custom_components
      },
      themes: {
        present: ($theme_file_count > 0),
        root_yaml_file_count: $theme_file_count,
        files: $theme_files
      },
      packages: {
        present: ($package_file_count > 0),
        root_yaml_file_count: $package_file_count,
        files: $package_files
      },
      esphome: {
        present: ($esphome_file_count > 0),
        root_yaml_file_count: $esphome_file_count,
        files: $esphome_files
      },
      www: {
        present: ($www_child_dir_count > 0),
        immediate_subdirectory_count: $www_child_dir_count,
        immediate_subdirectories: $www_child_dirs
      },
      local_addons: {
        present: ($local_addon_count > 0),
        manifest_count: $local_addon_count,
        manifests: $local_addon_manifests
      },
      www_lif_addons: {
        present: ($www_lif_addon_count > 0),
        count: $www_lif_addon_count,
        directories: $www_lif_addon_dirs
      }
    },
    repos: {
      count: $repo_count,
      self_hosted_remote_count: $self_hosted_repo_count,
      roots: $repos
    }
  }')
EOF

cat > "${PROFILE_FILE}" <<EOF
# HA Codex Instance Profile

Generated by \`/init\` on $(date -u +"%Y-%m-%d %H:%M:%SZ").
Detailed local discovery is stored in \`/data/ha-codex/instance-scan.json\`.

## Config Style

- Structure style: ${STRUCTURE_STYLE}
- ${STRUCTURE_SUMMARY}
- ${ROOT_GUIDANCE}
- Match the existing house style first. Do not reorganize configuration structure unless the user asks for it.

## Config Map

- \`configuration.yaml\` has ${CONFIG_LINES} lines and ${TOP_LEVEL_KEY_COUNT} top-level sections.
- Top-level include directives detected: ${INCLUDE_COUNT}
- Top-level include-directory directives detected: ${INCLUDE_DIR_COUNT}
- Top-level sections are mostly routed through includes: $( [ "${INCLUDE_COUNT}" -gt 0 ] && printf "yes" || printf "no" )
- Root-level sections still managed directly in \`configuration.yaml\`: ${DIRECT_ROOT_COUNT}
- Main top-level sections seen: $(preview_lines "${TOP_LEVEL_KEYS}")
- ${AUTOMATION_STATUS}
- ${SCRIPT_STATUS}

## Development Model

- Git repos discovered in this workspace: ${REPO_COUNT}
- Self-hosted or local git remotes detected: ${SELF_HOSTED_REPO_COUNT}
- Representative repo roots: $(preview_lines "$(printf '%s' "${REPO_JSON}" | jq -r '.[].path')")
- Local add-on manifests discovered under \`addons/local\`: ${LOCAL_ADDON_COUNT}
- Frontend add-on directories under \`www/lif-addons\`: ${WWW_LIF_ADDON_COUNT}
- This install appears to use multiple local source repos. Check the repo root from the file's directory before staging or committing.

## Work Areas

- \`custom_components/\`: $(dir_status "${CUSTOM_COMPONENTS_DIR}") (${CUSTOM_COMPONENT_COUNT} immediate subdirectories)
- \`themes/\`: $(dir_status "${THEMES_DIR}") (${THEME_FILE_COUNT} root YAML files)
- \`packages/\`: $(dir_status "${PACKAGES_DIR}") (${PACKAGE_FILE_COUNT} root YAML files)
- \`esphome/\`: $(dir_status "${ESPHOME_DIR}") (${ESPHOME_FILE_COUNT} root YAML files)
- \`www/\`: $(dir_status "${WWW_DIR}") (${WWW_CHILD_DIR_COUNT} immediate subdirectories)
- Dashboard YAML files at the config root: ${DASHBOARD_FILE_COUNT}
- Representative local add-on manifests: $(preview_lines "${LOCAL_ADDON_MANIFESTS}")
- Representative \`www/lif-addons\` dirs: $(preview_lines "${WWW_LIF_ADDON_DIRS}")

## Features Seen

- Lovelace configured: $(bool_word "${HAS_LOVELACE}")
- Shell commands configured: $(bool_word "${HAS_SHELL_COMMAND}")
- Command-line integrations configured: $(bool_word "${HAS_COMMAND_LINE}")
- Template includes/configuration present: $(bool_word "${HAS_TEMPLATE}")
- Sensor includes/configuration present: $(bool_word "${HAS_SENSOR}")
- REST commands configured: $(bool_word "${HAS_REST_COMMAND}")

## Environment Checks

- Home Assistant API check: ${API_STATUS}
- \`hass-mcp\` on PATH: ${MCP_BINARY_STATUS}
- ${MCP_SUMMARY}

## Include Patterns

$(markdown_include_map "${INCLUDE_LINES}")

## Working Rules

- In this add-on, translate HA Core-style \`/config/...\` paths to \`/homeassistant/...\`.
- When editing configuration, follow the existing placement pattern for similar items.
- Treat \`instance-profile.md\` as the compact startup memory and \`instance-scan.json\` as the deeper local discovery cache.
- Keep edits conservative and local to the relevant file or include path.
- Regenerate this profile with \`/init\` after a major config reorganization.
EOF

echo "[INFO] Wrote ${PROFILE_FILE}"
echo "[INFO] Wrote ${SCAN_FILE}"
if [ -x "${WRITE_INSTRUCTIONS_SCRIPT}" ]; then
  HA_CODEX_PERSIST_DIR="${PERSIST_DIR}" \
  HA_CODEX_INSTRUCTIONS_FILE="${INSTRUCTIONS_FILE}" \
  HA_CODEX_PROFILE_FILE="${PROFILE_FILE}" \
  HA_CODEX_SCAN_FILE="${SCAN_FILE}" \
    "${WRITE_INSTRUCTIONS_SCRIPT}" >/dev/null
  echo "[INFO] Refreshed ${INSTRUCTIONS_FILE}"
  echo "[INFO] The active add-on instructions now include the new profile without a restart."
elif [ -f "${WRITE_INSTRUCTIONS_SCRIPT}" ]; then
  HA_CODEX_PERSIST_DIR="${PERSIST_DIR}" \
  HA_CODEX_INSTRUCTIONS_FILE="${INSTRUCTIONS_FILE}" \
  HA_CODEX_PROFILE_FILE="${PROFILE_FILE}" \
  HA_CODEX_SCAN_FILE="${SCAN_FILE}" \
    bash "${WRITE_INSTRUCTIONS_SCRIPT}" >/dev/null
  echo "[INFO] Refreshed ${INSTRUCTIONS_FILE}"
  echo "[INFO] The active add-on instructions now include the new profile without a restart."
else
  echo "[WARN] Instruction refresh helper not found at ${WRITE_INSTRUCTIONS_SCRIPT}"
  echo "[WARN] The new profile is saved, but startup instructions will refresh on next add-on restart."
fi
