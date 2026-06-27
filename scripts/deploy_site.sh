#!/usr/bin/env bash
#
# deploy_site.sh — publish the landing page to the live site.
#
# The site is NOT served from this repo. It lives in the hub repo
# `jimmyrentmeester.github.io` (GitHub Pages, user site), with each app in its
# own subfolder. This repo's docs/site/ is only the SOURCE; this script syncs it
# into the hub repo's gridbreaker/ folder, commits, pushes, and verifies live.
#
# Usage:  scripts/deploy_site.sh ["optional commit message"]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/docs/site/"
HUB_DIR="${GRIDBREAKER_HUB:-$HOME/jimmyrentmeester.github.io}"
HUB_REMOTE="https://github.com/jimmyrentmeester/jimmyrentmeester.github.io.git"
SUBFOLDER="gridbreaker"
LIVE_URL="https://jimmyrentmeester.github.io/$SUBFOLDER/"
MSG="${1:-"gridbreaker: deploy site update from docs/site"}"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

# 1. Ensure the hub repo is present and up to date.
if [ ! -d "$HUB_DIR/.git" ]; then
  say "Cloning hub repo into $HUB_DIR"
  git clone --quiet "$HUB_REMOTE" "$HUB_DIR"
else
  say "Updating hub repo ($HUB_DIR)"
  git -C "$HUB_DIR" pull --quiet --ff-only
fi

DST="$HUB_DIR/$SUBFOLDER/"

# 2. Mirror source -> hub subfolder (--delete prunes removed assets).
say "Syncing $SRC -> $DST"
rsync -a --delete --exclude README.md --exclude .DS_Store "$SRC" "$DST"

# 3. Commit + push (no-op if nothing changed).
cd "$HUB_DIR"
git add -A "$SUBFOLDER/"
if git diff --cached --quiet; then
  say "No changes to deploy — site already up to date."
  exit 0
fi
git commit --quiet -m "$MSG"
say "Pushing to hub repo"
git push --quiet origin HEAD

# 4. Wait for the GitHub Pages build, then confirm the live site updated.
COMMIT="$(git rev-parse HEAD)"
say "Waiting for GitHub Pages build ($COMMIT)"
for i in $(seq 1 40); do
  status="$(gh api repos/jimmyrentmeester/jimmyrentmeester.github.io/pages/builds/latest --jq .status 2>/dev/null || echo '?')"
  if [ "$status" = "built" ]; then
    printf 'build=built after ~%ss\n' "$((i*15))"
    break
  fi
  printf 't=%ss build=%s\n' "$((i*15))" "$status"
  sleep 15
done

say "Live site: $LIVE_URL"
echo "Tip: GitHub Pages + browsers cache aggressively — hard-refresh (Cmd+Shift+R) to see changes."
