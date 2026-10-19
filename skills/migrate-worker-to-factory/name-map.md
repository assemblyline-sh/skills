# Name map: worker repo → factory repo

What changes between a repo on `@fob/lib-worker` 0.35.0 and one on
`@assemblyline/lib-factory` 0.1.0. `scripts/apply-renames.sh` does the rows marked
**script**; the rest need a look.

## In the repo

| Where | Worker | Factory | |
|---|---|---|---|
| `package.json` name | `worker-<name>` | `factory-<name>` | script |
| `package.json` dependency | `"@fob/lib-worker": "github:finopsbricks/lib-worker#v0.35.0"` | `"@assemblyline/lib-factory": "github:assemblyline-sh/lib-factory#v0.2.0"` | script |
| Imports | `from '@fob/lib-worker'` | `from '@assemblyline/lib-factory'` | script |
| Entry point | `startWorker({ getHandler, callerUrl })` | `startFactory({ getHandler, callerUrl })` | script |
| Env | `WORKER_LOCATION` | `FACTORY_LOCATION` | script (`.env.example`, `src/`, `scripts/`, `tests/`) |
| Conveyor step slug in station files | `lib-worker:move_files` | `lib-factory:move_files` | script |
| Repo pointer | `.orchestrator/worker.json` | `.orchestrator/factory.json` (`orchestrator_url`, `org`) | script |
| Env, unchanged | `ORCHESTRATOR_URL`, `ORCHESTRATOR_API_KEY`, `ORCHESTRATOR_API_SECRET`, `POLL_INTERVAL_MS` | same | |
| Layout, unchanged | `.orchestrator/{lines,stations,scenarios}`, `temp/stations/<ST>/<bin>/`, `pointer.json`, `log.jsonl` | same | |
| Station libraries, unchanged | `@fob/lib-worker-ai`, `@fob/lib-worker-email`, `@fob/lib-worker-google`, `@fob/stm` | same: none of them imports lib-worker | |
| CLIs | `fob-worker`, `fob-orc` | `al-factory`, `al-orc` (same commands); `fob-worker steps …` is `npx factory steps …` (ships with lib-factory) | docs: by hand |
| CLI config | `~/.fob/fob-orc/config.yml` | `~/.assemblyline/al-orc/config.yml` | |

## Removed from the runtime

Search for each; the script reports hits but doesn't change them.

| Gone | Instead |
|---|---|
| `findItemByExternalId`, `createItem`, `findOrCreateItem` | Nothing: the item API no longer exists. Drop the call, or keep the data in the workpiece. |
| `runProcess()` | `al-orc stations run <id>`, or `POST /api/v1/stations/:id/run` |
| `work_record.item_snapshot` | Neither orchestrator sends it any more. Stations that read it were already broken; leave them out of the plan, or cast to keep the typecheck green: `/** @type {any} */ (work_record).item_snapshot` |
| `validateEnv(options)` | `validateEnv()` takes no options |

## Words in docs and comments

The running process is a **factory session**, the repo is a **factory**, a **station** was
once a *process*. "Worker" names nothing in Assembly Line (on assemblyline.sh a worker is a
person). Rewrite README, CLAUDE.md and comments by hand. Leave decision records and finished
WIP history as they are, apart from commands someone might copy.

## Older lib-worker versions

Check `@fob/lib-worker` in the worker's `package.json`. Below 0.35.0, these also apply (from
the lib-worker changelog):

- **Below 0.35.0:** nothing breaking. 0.35.0 added the intake watch (`watch_path` on a
  line-head's step 0).
- **Below 0.34.0:** bins move workpieces only: a workpiece is a folder holding a
  `pointer.json`, and loose files are left alone. `move_files` lost its files mode: `mode:
  "files"`, `pattern` and `recursive` now fail the step. `splitBundlesStep`
  (`lib-worker:split_bundles`) is gone: drop its import and registration in `src/index.js`.
  `moveFiles()` is now `moveWorkpieces({ source_dir, target_dir, batch_size })`. A line that
  still moves loose files has to move to workpiece folders first. That's a change to the
  line, so plan it with the user before the migration.
- **Below 0.33.0:** the bin watcher finds its stations through their **line**: it reads
  `.orchestrator/lines/*.json`, keeps lines whose `location` matches the session's location,
  and watches their stations. Station files lose `location` and must carry `line`. Pull the
  lines (`al-orc lines pull --all`) and check every station file has a `line`.
