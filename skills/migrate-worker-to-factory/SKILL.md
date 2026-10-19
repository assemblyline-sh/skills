---
name: migrate-worker-to-factory
description: Migrate a FinOpsBricks worker repo (worker-<name>, built on @fob/lib-worker) to an Assembly Line factory repo (factory-<name>, built on @assemblyline/lib-factory), then move its lines live one at a time from the FinOpsBricks orchestrator to the Assembly Line orchestrator. Use when someone asks to migrate, port or convert a worker, worker repo or lib-worker code to a factory or to Assembly Line.
argument-hint: "[path to the worker repo]"
---

# Migrate a worker to a factory

Turns `worker-<name>` into `factory-<name>` and moves its lines to the Assembly Line
orchestrator without running any line on two engines at once. The worker repo is copied, not
renamed: it keeps running on FinOpsBricks until each of its lines has moved.

The migration has two halves, and they're done at different speeds:

1. **Convert the code** (phases 1–4): a copy of the repo with the renames applied, tested,
   with every trigger off. Nothing runs yet. This can be done in one sitting.
2. **Move the lines** (phases 5–7): one line at a time, switch it off on FinOpsBricks, carry
   its state across, switch it on here, watch it run. Spread over hours or days.

## Ground rules

- **One engine per line.** Before a line's triggers go on here, they are off on FinOpsBricks
  and its in-flight work has finished.
- **Ask before anything outside the new repo:** creating the GitHub repo, pushing station
  files, switching FinOpsBricks schedules off, stopping or starting processes on a machine.
  Show what you will change and wait for a yes.
- **Never print secrets.** Read `.env` files by key name only (`grep -E '^[A-Z_]+=' .env |
  cut -d= -f1`). Copy them whole with `cp`, edit with `sed` on the line you mean, and never
  `cat` or `grep` a value.
- **Keep state out of this skill.** The run plan and progress for this migration live in the
  new repo, in `docs/wip/migrate-from-worker-<name>.md`. Create it in phase 1, update it at
  the end of every phase, and read it first if you're picking up a migration halfway.
- **Fictional examples** in anything you write that could be shared (`acme`, `globex`).

## Before you start

Check these and stop if one fails; the fix is in [troubleshooting.md](troubleshooting.md).

- `al-orc` and `al-factory` are installed. `al-orc status` shows the right org on the Assembly
  Line orchestrator. If the org was imported from FinOpsBricks, the worker's existing API key
  works there: copy its profile from `~/.fob/fob-orc/config.yml` with the URL changed
  ([cutover.md](cutover.md#cli-profiles)).
- `al-orc stations list` shows the worker's stations. Imported stations arrive with
  schedules off.
- You know which machine runs the worker today and how (usually pm2), and you can reach it.

## Phase 1: Survey

Run `scripts/scan-worker.sh <worker-dir>` and read the whole output. It lists the lib-worker
version, the imports and calls to rename, each line with its location and the stations that
belong to it, each station's triggers, the intake registries in `temp/`, and the env key
names.

From it, write the run plan into the new WIP file: one row per line with its location,
trigger, what it reads, what it writes outside its own bins, what happens if it runs twice,
and the order you'll move it in. Read-only and manual lines go first; lines that write to
outside systems on a schedule go last. The table format and how to judge each column are in
[run-plan.md](run-plan.md).

Watch for:
- Line files for lines whose stations live in another repo. A line belongs to the repo that
  holds its station files; leave the others out of the plan.
- A lib-worker older than 0.35.0: it brings extra breaking changes
  ([name-map.md](name-map.md#older-lib-worker-versions)).
- A line whose location is a machine the worker doesn't run on. Ask where it should run.

## Phase 2: Copy the repo

Ask the user where the factory repo lives (GitHub org, name `factory-<name>`, visibility).
Then copy it with its history:

```bash
git clone --no-hardlinks <worker-dir> <factories-dir>/factory-<name>
cd <factories-dir>/factory-<name>
git remote rename origin finopsbricks
git remote add origin git@github.com:<org>/factory-<name>.git
```

Create the empty GitHub repo (`gh repo create <org>/factory-<name> --private`) only after the
user says yes, then push. First commit: one line in CLAUDE.md saying this is the Assembly
Line fork of the worker, and that the `finopsbricks` remote is never pushed to.

## Phase 3: Convert the code

From the new repo's root, run `scripts/apply-renames.sh factory-<name> <org>` (the org as
in `.orchestrator/worker.json`), then go through
[name-map.md](name-map.md) for what the script can't decide: docs and comments that say
"worker", `item_snapshot` reads, removed APIs, and older-version changes. The script also
replaces `.orchestrator/worker.json` with `.orchestrator/factory.json`, pointing at the
Assembly Line orchestrator. The `@fob/*` station libraries (`lib-worker-ai`, `-email`, `-google`,
`@fob/stm`) stay: they don't import lib-worker.

Then switch every trigger off in the station files: `schedule_enabled: false` and
`watch_enabled: false` on every station. Each line's flags come back when it moves.

## Phase 4: Verify, then push definitions

- `npm install`, then `npm test` and `npm run typecheck`. Run both in the worker repo first
  and compare: tests that already failed there may fail here, and the typecheck may have
  fewer errors (lib-factory fixed some JSDoc types), but nothing new may appear.
- `al-factory steps list` loads every step. Run one read-only step locally if there is one.
- Push the lines and stations the plan covers, one by one so lines from other repos aren't
  touched: `al-orc lines push <CODE>` and `al-orc stations push <file> --force` (keeps ids,
  so `dependencies` still resolve).
- Confirm with `al-orc stations list` that every pushed station shows schedule and watch off.
- Commit and push the repo.

## Phase 5: Start an idle factory session

On the machine the worker runs on, ask first, then: clone the factory repo, `npm install`,
copy the worker's `.env` and change only `ORCHESTRATOR_URL` and `WORKER_LOCATION` →
`FACTORY_LOCATION`, and start it the way the worker runs (`pm2 start src/index.js --name
factory-<name>`). The log must show `Session established` and the right location, and the
bin watcher's warning should list every station as untriggered. Details:
[cutover.md](cutover.md#start-the-factory-session).

## Phase 6: Move the lines, one at a time

For each line in plan order, follow [cutover.md](cutover.md#move-one-line). In short:

1. Switch its triggers off on FinOpsBricks (schedule flags in the worker's station files,
   pushed with `fob-orc stations push`, committed in the worker repo). Do it before the
   next cron slot.
2. Wait until it is idle: no running work records for its stations, nothing in its `doing/`
   or `input/` bins.
3. Copy its `temp/stations/<STATION>/` folders from the worker checkout into the factory
   checkout, intake registries included. Without them the line-head treats everything it
   has ever seen as new.
4. Switch its triggers on in the factory's station files, push those stations, commit, pull
   on the machine and restart the factory session (watches are read at start).
5. Watch the next scheduled run and start one by hand with `al-orc stations run <HEAD>`. The
   report should show already-captured items skipped, not seeded again.

Update the WIP after every line.

## Phase 7: Stop the worker

When every line in the plan has moved, check that nothing else of the worker is active on
FinOpsBricks, then (after a yes) `pm2 stop worker-<name> && pm2 save`. Keep it stopped, not
deleted, for a week. Record in the WIP what moved, what stayed and why, and anything that
broke. Suggest rotating the API key if it was ever displayed.

## Related

- [name-map.md](name-map.md): every rename, and the breaking changes by lib-worker version
- [run-plan.md](run-plan.md): how to judge each line and order the moves
- [cutover.md](cutover.md): CLI profiles, starting the session, moving one line, rollback
- [troubleshooting.md](troubleshooting.md): what went wrong in earlier migrations
