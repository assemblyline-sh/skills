#!/usr/bin/env bash
# Apply the mechanical worker → factory renames in a copied repo. Run from the factory repo's
# root, after the copy and before any hand edits. Docs, comments and removed APIs are left
# for you; the script lists what it couldn't decide.
#
#   apply-renames.sh <factory-name> <org> [lib-factory tag, default v0.1.0]
set -euo pipefail

name="${1:?usage: apply-renames.sh <factory-name> <org> [tag]}"
org="${2:?usage: apply-renames.sh <factory-name> <org> [tag]}"
tag="${3:-v0.1.0}"
url="https://orchestrator.assemblyline.sh"

[[ -f package.json ]] || { echo "Run from the repo root" >&2; exit 1; }
[[ "$name" == factory-* ]] || { echo "The name should start with factory-" >&2; exit 1; }

code_files=$(grep -rlE "@fob/lib-worker'|startWorker|WORKER_LOCATION" src scripts tests test .env.example 2>/dev/null || true)
station_files=$(grep -l '"lib-worker:' .orchestrator/stations/*.json 2>/dev/null || true)

# package.json: name and the runtime dependency
node -e '
  const fs = require("fs");
  const [name, tag] = process.argv.slice(1);
  const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
  p.name = name;
  if (p.dependencies && p.dependencies["@fob/lib-worker"]) {
    const deps = {};
    for (const [k, v] of Object.entries(p.dependencies)) {
      if (k === "@fob/lib-worker") deps["@assemblyline/lib-factory"] = `github:assemblyline-sh/lib-factory#${tag}`;
      else deps[k] = v;
    }
    p.dependencies = Object.fromEntries(Object.entries(deps).sort(([a], [b]) => a.localeCompare(b)));
  }
  fs.writeFileSync("package.json", JSON.stringify(p, null, 2) + "\n");
' "$name" "$tag"
echo "package.json: name $name, @assemblyline/lib-factory#$tag"

# Code: imports, entry point, env name
for f in $code_files; do
  perl -pi -e "s#from '\@fob/lib-worker'#from '\@assemblyline/lib-factory'#g; s/\bstartWorker\b/startFactory/g; s/\bWORKER_LOCATION\b/FACTORY_LOCATION/g" "$f"
  echo "code: $f"
done

# Station files: the conveyor slug
for f in $station_files; do
  perl -pi -e 's/"lib-worker:/"lib-factory:/g' "$f"
  echo "station: $f"
done

# Repo pointer
if [[ -f .orchestrator/worker.json ]]; then
  git mv .orchestrator/worker.json .orchestrator/factory.json 2>/dev/null || mv .orchestrator/worker.json .orchestrator/factory.json
fi
node -e '
  const fs = require("fs");
  const [url, org] = process.argv.slice(1);
  fs.writeFileSync(".orchestrator/factory.json", JSON.stringify({ orchestrator_url: url, org }, null, 2) + "\n");
' "$url" "$org"
echo ".orchestrator/factory.json → $url, org $org"

echo
echo "Left for you (see name-map.md):"
grep -rnE "findItemByExternalId|createItem|findOrCreateItem|runProcess|item_snapshot|splitBundlesStep|moveFiles\(|validateEnv\([^)]+\)|@fob/lib-worker['\"]" src scripts tests test 2>/dev/null | sed 's/^/  /' || true
echo "  docs and comments that say worker: $(grep -rliE '\bworker\b' --include='*.md' . 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ') markdown files"
echo
echo "Next: npm install, npm test, npm run typecheck, al-factory steps list"
