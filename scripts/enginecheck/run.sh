#!/usr/bin/env bash
# Run the deterministic Core engine checks (no simulator). Each check file uses
# top-level code, which swiftc only allows in a file named main.swift — so we copy
# each into a temp dir as main.swift, compile it with the Core value types, and run.
#
#   scripts/enginecheck/run.sh            # run all checks
#   scripts/enginecheck/run.sh daemonset  # run one (by file stem)
set -euo pipefail
cd "$(dirname "$0")/../.."

CORE=(
  App/GRID_BREAKER/Core/Engine/GridEngine.swift
  App/GRID_BREAKER/Core/Models/GameConfig.swift
  App/GRID_BREAKER/Core/Models/GridNode.swift
  App/GRID_BREAKER/Core/Models/NodeType.swift
  App/GRID_BREAKER/Core/Models/Cyberdeck.swift
  App/GRID_BREAKER/Core/Models/Campaign.swift
)

checks=("${@:-daemonset dmz}")
status=0
for name in ${checks[@]}; do
  src="scripts/enginecheck/${name}.swift"
  [ -f "$src" ] || { echo "no such check: $src"; status=1; continue; }
  build="$(mktemp -d)"
  cp "$src" "$build/main.swift"
  echo "=== ${name} ==="
  swiftc -O "${CORE[@]}" "$build/main.swift" -o "$build/run" 2>&1 | grep -v "warning:" || true
  "$build/run" || status=1
  rm -rf "$build"
done
exit $status
