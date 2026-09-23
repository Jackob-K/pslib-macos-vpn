#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/bin"
TARGET="${TARGET_DIR}/pslib-vpn"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Tento nástroj je určen pro macOS." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Homebrew nebyl nalezen.
Nainstaluj jej podle oficiálního návodu na https://brew.sh a spusť instalátor znovu.
EOF
  exit 1
fi

echo "Instaluji závislosti…"
brew install sstp-client ca-certificates

mkdir -p "$TARGET_DIR"
install -m 0755 "$ROOT/bin/pslib-vpn" "$TARGET"

case ":$PATH:" in
  *":$TARGET_DIR:"*) ;;
  *)
    PROFILE="${HOME}/.zprofile"
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$PROFILE"
    echo "Do $PROFILE bylo přidáno ~/.local/bin."
    echo "Po instalaci spusť: source ~/.zprofile"
    ;;
esac

echo "Nainstalováno: $TARGET"
echo "Další krok: pslib-vpn setup"
