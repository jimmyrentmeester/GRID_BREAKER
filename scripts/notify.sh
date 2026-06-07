#!/usr/bin/env bash
# macOS banner notifications for GRID_BREAKER runs.
# Source this file: `source scripts/notify.sh`, then call the functions.

notify_update() {
  local title="${1:-GRID_BREAKER}"
  local text="${2:-Run done.}"
  /usr/bin/osascript -e "display notification \"${text//\"/\\\"}\" with title \"${title//\"/\\\"}\" sound name \"Glass\"" >/dev/null 2>&1
}

notify_blocked() {
  local reason="${1:-unknown}"
  /usr/bin/osascript -e "display notification \"${reason//\"/\\\"}\" with title \"GRID_BREAKER: ❌ blocked\" sound name \"Funk\"" >/dev/null 2>&1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  notify_update "GRID_BREAKER notify-test" "Notifications work."
  echo "Test notification sent."
fi
