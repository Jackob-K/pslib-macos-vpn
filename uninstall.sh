#!/usr/bin/env bash
set -Eeuo pipefail

TARGET="${HOME}/.local/bin/pslib-vpn"
CONFIG_DIR="${HOME}/.config/pslib-vpn"

if [[ -x "$TARGET" ]]; then
  "$TARGET" disconnect || true
  "$TARGET" forget-credentials || true
fi

rm -f "$TARGET"
rm -f "$CONFIG_DIR/username" "$CONFIG_DIR/settings"
rm -f "$CONFIG_DIR/run/mounted-volumes"
rm -f "$CONFIG_DIR/run/managed-route"
rmdir "$CONFIG_DIR/run/connect.lock" 2>/dev/null || true
rmdir "$CONFIG_DIR/run" 2>/dev/null || true
rmdir "$CONFIG_DIR" 2>/dev/null || true

printf 'pslib-vpn byl odinstalovan.\n'
printf 'Homebrew balicky zustaly zachovane; lze je odebrat rucne.\n'
