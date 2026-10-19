# Troubleshooting

Problems met in earlier migrations, and what fixed them.

| Symptom | Cause | Fix |
|---|---|---|
| `al-orc status` fails with the copied key | The org hasn't been imported into the Assembly Line orchestrator, or the key's org was marked for deletion | Ask the Assembly Line team to import the org, or create a new key in Settings → API keys |
| `API key lacks stations:read permission` | A key created before scopes were renamed (`processes` → `stations`) | Re-import the org, or create a new key |
| The session starts but the bin watcher lists every station as untriggered | Expected during the conversion: every trigger is off | Switch a line's flags on when it moves (cutover step 4) |
| A watched station never fires after its flags went on | The session read the station files before the change | `git pull` on the machine and restart the factory session |
| A scheduled station didn't run at the slot | `schedule_enabled` is still off in the orchestrator (the push didn't include it), or the job runner is down | `al-orc stations show <ST>`; push the station file again |
| The first run here seeded everything again | The intake registry wasn't copied | Stop the line, delete what it seeded, copy `intake-registry.jsonl` from the worker, run again |
| Station push says "Tags cleared" | The station file has no `tags`; push makes the orchestrator match the file | Add the tags to the file, or accept it. Tags only label stations |
| A conveyor moves one batch per run and leaves the rest | `move_files` moves `batch_size` workpieces per run, by design | Run it again, or raise `batch_size` in the station file |
| Boot error: `has no line` / no `.orchestrator/lines/` | Repo from before lib-worker 0.33.0 | `al-orc lines pull --all`, then add `line` to each station file |
| Boot error about `watch_enabled` without a conveyor or `watch_path` | A watched line-head with no inbox to watch | Give step 0 a `watch_path`, or schedule it instead |
| `npm install` fails on `github:assemblyline-sh/lib-factory` | No access to the repo, or the tag doesn't exist | Check `git ls-remote git@github.com:assemblyline-sh/lib-factory.git` and the tag in `package.json` |
| A station ran the moment its schedule went on, not at the next slot | A slot was missed since `last_run_at`, and the scheduler catches it up | Expected. Switch schedules on just after a slot, and use that run as the first check |
| `Poll error: fetch failed` a few times in the factory log, then normal | A short network drop between the machine and the orchestrator; the session polls again | Nothing to do if it stops on its own. If it repeats, check the machine's network and `ORCHESTRATOR_URL` |
| The factory copy is missing code the worker runs | The worker's checkout had uncommitted or unpushed changes when it was copied | Commit and push them in the worker, then pull them into the factory repo (`git pull finopsbricks main`) and redo the renames on the new files |
| Jest aborts with a Watchman `dyld` or socket error | A broken Watchman install, unrelated to the migration | `npm test -- --no-watchman` |
| Tests fail after the conversion | Compare with the worker repo first: suites that import moved files may already fail there | Only new failures count |
| The worker folder can't be deleted: the factory lacks `temp/work_records/` | The run logs weren't carried at the stop | `rsync -a --ignore-existing <worker>/temp/work_records/ <factory>/temp/work_records/`, then retire as in cutover.md |
| A secret appeared in the output | A command printed `.env` values | Tell the user, and rotate that key once the migration is done |
