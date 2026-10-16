#!/usr/bin/env bash
# ==============================================================================
# Dokploy Local CLI Uninstaller
# ==============================================================================
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SRC_DIR/install.sh" ]; then
  exec "$SRC_DIR/install.sh" --uninstall "$@"
else
  echo "Error: install.sh not found." >&2
  exit 1
fi
