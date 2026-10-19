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
| Jest aborts with a Watchman `dyld` or socket error | A broken Watchman install, unrelated to the migration | `npm test -- --no-watchman` |
| Tests fail after the conversion | Compare with the worker repo first: suites that import moved files may already fail there | Only new failures count |
| A secret appeared in the output | A command printed `.env` values | Tell the user, and rotate that key once the migration is done |
