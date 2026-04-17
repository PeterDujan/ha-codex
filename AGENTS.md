# HA-Codex Repository Instructions

This repository contains the standalone Home Assistant add-on for Codex.

## Boundaries

- Keep the primary add-on in `ha-codex/`.
- Any new add-on folder, persistent runtime folder, or add-on-specific path must begin with `ha-codex`.
- Do not share auth, mounts, folders, or runtime state with other add-ons.

## Before Every Commit

Update the relevant `CHANGELOG.md` before committing:

- `ha-codex/CHANGELOG.md` for the Codex terminal add-on.

## Project Structure

- `repository.yaml` - Add-on repository metadata.
- `ha-codex/` - Codex CLI add-on.

## Home Assistant Add-on Notes

- Bump `config.yaml` versions when publishing changes.
- Base images use Home Assistant add-on conventions and `BUILD_FROM`.
- Keep persistent Codex state in `/data/ha-codex`; do not use auth or runtime state from other local add-ons.
