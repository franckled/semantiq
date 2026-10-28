#!/usr/bin/env bash
# Dépose les journaux d'un job en échec dans la branche ci-logs-<job>, pour
# pouvoir les lire hors de GitHub (aucun secret n'y figure).
# Usage : push_logs.sh <job> <jeton> <owner/dépôt>
set -uo pipefail

JOB="$1"
TOKEN="$2"
REPO="$3"
LOGS="${RUNNER_TEMP:-/tmp}/logs"
mkdir -p "$LOGS"

# Fichiers de configuration utiles au diagnostic.
for f in pubspec.lock ios/Podfile android/app/build.gradle.kts \
         android/app/src/main/AndroidManifest.xml; do
  [[ -f $f ]] && cp "$f" "$LOGS/$(echo "$f" | tr '/' '_')"
done
echo "$JOB ${GITHUB_RUN_ID:-} ${GITHUB_SHA:-}" > "$LOGS/README"

cd "$LOGS"
git init -q -b "ci-logs-$JOB"
git add -A
git -c user.name=ci -c user.email=ci@users.noreply.github.com \
  commit -qm "logs $JOB ${GITHUB_RUN_ID:-}"
git push -qf "https://x-access-token:${TOKEN}@github.com/${REPO}" "ci-logs-$JOB"
