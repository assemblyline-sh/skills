#!/usr/bin/env bash
# Survey a worker repo before migrating it to a factory. Read-only; prints no secret values.
#
#   scan-worker.sh <worker-dir>
set -euo pipefail

dir="${1:?usage: scan-worker.sh <worker-dir>}"
cd "$dir"
[[ -f package.json ]] || { echo "No package.json in $dir" >&2; exit 1; }

section() { printf '\n== %s\n' "$1"; }
src_dirs=$(for d in src scripts tests test; do if [[ -d $d ]]; then printf "%s " "$d"; fi; done)

section "Package"
node -e '
  const p = require("./package.json");
  const deps = { ...p.dependencies, ...p.devDependencies };
  console.log("name:", p.name);
  console.log("@fob/lib-worker:", deps["@fob/lib-worker"] || "(not a dependency)");
  for (const [k, v] of Object.entries(deps)) if (k.startsWith("@fob/") && k !== "@fob/lib-worker") console.log("keeps:", k, v);
  console.log("scripts:", Object.keys(p.scripts || {}).join(", "));
'

section "lib-worker imports and calls to change"
# shellcheck disable=SC2086
grep -rnoE "from '@fob/lib-worker'|startWorker|WORKER_[A-Z_]+|findItemByExternalId|createItem|findOrCreateItem|runProcess|item_snapshot|splitBundlesStep|moveFiles\(|validateEnv\([^)]+\)" $src_dirs 2>/dev/null \
  | awk -F: '{ print $3 }' | sort | uniq -c | sort -rn || true
echo "files with hits:"
# shellcheck disable=SC2086
grep -rlE "@fob/lib-worker'|startWorker|WORKER_|item_snapshot|runProcess|createItem|findItemByExternalId|splitBundlesStep" $src_dirs 2>/dev/null | sed 's/^/  /' || true

section "Git state (commit and push before copying)"
echo "branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(not a git repo)')  head: $(git rev-parse --short HEAD 2>/dev/null || echo -)"
changed=$(git status --porcelain 2>/dev/null | { grep -v '^??' || true; } | wc -l | tr -d ' ')
untracked=$(git status --porcelain 2>/dev/null | { grep '^??' || true; } | wc -l | tr -d ' ')
unpushed=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo "no upstream")
echo "uncommitted changes: $changed  untracked files: $untracked  unpushed commits: $unpushed"
if [[ $changed != 0 || $unpushed != 0 ]]; then
  echo "  -> commit and push these first, or the factory copy won't have them"
fi
echo "Compare with the checkout on the machine that runs the worker: same head, same diff?"

section "Lines (location) and the stations in this repo that belong to each"
node -e '
  const fs = require("fs"), path = require("path");
  const read = (d) => fs.existsSync(d) ? fs.readdirSync(d).filter((f) => f.endsWith(".json")).map((f) => ({ f, j: JSON.parse(fs.readFileSync(path.join(d, f), "utf8")) })) : [];
  const lines = read(".orchestrator/lines"), stations = read(".orchestrator/stations");
  const by_line = {};
  for (const { f, j } of stations) (by_line[j.line || "(no line)"] ||= []).push({ f, j });
  for (const { j } of lines) {
    const own = by_line[j.code] || [];
    console.log(`${j.code}  location=${j.location}  stations here=${own.length}${own.length ? "" : "  <- stations live in another repo"}`);
  }
  for (const code of Object.keys(by_line)) if (!lines.find(({ j }) => j.code === code)) console.log(`${code}  (no line file)  stations here=${by_line[code].length}`);
  console.log("\nStation triggers:");
  for (const { f, j } of stations.sort((a, b) => a.f.localeCompare(b.f))) {
    const steps = (j.steps || []).map((s) => s.slug);
    const step0 = (j.steps || [])[0] || {};
    const cfg = step0.config || {};
    const trig = [j.schedule_enabled ? `cron "${j.schedule_cron}" ${j.schedule_timezone || ""}`.trim() : null, j.watch_enabled ? (cfg.watch_path ? `intake watch ${cfg.watch_path}` : "bin watch") : null].filter(Boolean).join(" + ") || "manual";
    const flags = [];
    if (steps.some((s) => s && s.startsWith("lib-worker:"))) flags.push("lib-worker slug");
    if (steps.includes("lib-worker:split_bundles")) flags.push("split_bundles (removed in 0.34)");
    if (cfg.mode === "files" || cfg.pattern || cfg.recursive) flags.push("move_files files mode (removed in 0.34)");
    if (!j.line) flags.push("no line");
    console.log(`  ${(j.short_code || f).padEnd(10)} line=${(j.line || "-").padEnd(8)} ${trig}${flags.length ? "  [" + flags.join(", ") + "]" : ""}`);
  }
'

section "Repo pointer"
for f in .orchestrator/worker.json .orchestrator/factory.json; do
  if [[ -f $f ]]; then echo "$f:"; cat "$f"; echo; fi
done

section "Env key names (values not shown)"
for f in .env.example .env; do
  if [[ -f $f ]]; then echo "$f: $(grep -E '^[A-Z_][A-Z0-9_]*=' "$f" | cut -d= -f1 | tr '\n' ' ')"; fi
done

section "Bin state in temp/ (registries and waiting workpieces)"
if [[ -d temp/stations ]]; then
  for st in temp/stations/*/; do
    st=${st%/}; name=${st##*/}; out=""
    if [[ -f $st/intake-registry.jsonl ]]; then out+="registry=$(wc -l < "$st/intake-registry.jsonl" | tr -d ' ') "; fi
    for b in input doing output failed; do
      if [[ -d $st/$b ]]; then out+="$b=$(find "$st/$b" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ') "; fi
    done
    printf '  %-10s %s %s\n' "$name" "$out" "($(du -sh "$st" | cut -f1))"
  done
else
  echo "  no temp/stations here (state lives in the checkout on the machine that runs the worker)"
fi

section "Tests"
echo "Run 'npm test' here before converting: suites that fail now may fail after; nothing else may."
