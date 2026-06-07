#!/usr/bin/env bash
# Manual trigger for a new Claude Code session on GRID_BREAKER.
# Uses scripts/next_task.md as the prompt. No scheduler — you pick the moment.

set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"

if ! command -v claude >/dev/null 2>&1; then
  echo "❌ 'claude' CLI not found in PATH. Install Claude Code first."
  exit 1
fi

if [[ ! -f "scripts/next_task.md" ]]; then
  echo "❌ scripts/next_task.md missing."
  exit 1
fi

echo "→ Starting Claude Code session in $PROJECT_DIR"
echo "→ Prompt: scripts/next_task.md"
echo

# -p = print mode (non-interactive). Default model = Sonnet (budget-aware).
# --dangerously-skip-permissions: needed in -p mode so tool calls don't hang.
claude --model sonnet \
  --dangerously-skip-permissions \
  -p "$(cat scripts/next_task.md)"
