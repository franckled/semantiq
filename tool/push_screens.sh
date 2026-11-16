#!/usr/bin/env bash
# Dépose les captures d'écran (build/screens) dans la branche ci-screens,
# pour pouvoir les regarder hors de GitHub Actions.
# Usage : push_screens.sh <jeton> <owner/dépôt>
set -uo pipefail

TOKEN="$1"
REPO="$2"
DIR="build/screens"
[[ -d $DIR ]] || { echo "Aucune capture."; exit 0; }

echo "captures ${GITHUB_RUN_ID:-} ${GITHUB_SHA:-}" > "$DIR/README"
cd "$DIR"
git init -q -b ci-screens
git add -A
git -c user.name=ci -c user.email=ci@users.noreply.github.com \
  commit -qm "captures ${GITHUB_RUN_ID:-}"
git push -qf "https://x-access-token:${TOKEN}@github.com/${REPO}" ci-screens
