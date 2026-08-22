#!/bin/bash
set -eo pipefail

ACTION="${1:-}"
PARAM="${2:-}"

GH_BIN=""
if command -v mise >/dev/null 2>&1; then
  GH_BIN="$(mise which gh 2>/dev/null || true)"
fi
if [[ -z "$GH_BIN" || ! -x "$GH_BIN" ]]; then
  GH_BIN="$(command -v gh 2>/dev/null || true)"
fi
if [[ -z "$GH_BIN" || ! -x "$GH_BIN" ]]; then
  for candidate in "$HOME/.local/bin/gh" "$HOME/.local/share/mise/installs/gh/latest/gh_*/bin/gh" "/usr/bin/gh" "/usr/local/bin/gh"; do
    matched=($candidate)
    if [[ -x "${matched[0]}" ]]; then
      GH_BIN="${matched[0]}"
      break
    fi
  done
fi

case "$ACTION" in
  mark-read)
    if [[ -n "$PARAM" && -n "$GH_BIN" ]]; then
      "$GH_BIN" api -X PATCH "/notifications/threads/$PARAM" >/dev/null 2>&1 || true
    fi
    ;;
  mark-all-read)
    if [[ -n "$GH_BIN" ]]; then
      "$GH_BIN" api -X PUT "/notifications" >/dev/null 2>&1 || true
    fi
    ;;
  open)
    if [[ -n "$PARAM" ]]; then
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$PARAM" >/dev/null 2>&1 &
      fi
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac

exit 0
