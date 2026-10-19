# Cutover

Moving lines from the worker on FinOpsBricks to the factory on Assembly Line.

## CLI profiles

`al-orc` reads `~/.assemblyline/al-orc/config.yml`, the same format as fob-orc's
`~/.fob/fob-orc/config.yml` (`current_org`, then `orgs.<profile>.{api_url, api_key,
api_secret}`). When the org was imported from FinOpsBricks, its API keys came with it, so the
quickest setup is a copy of the fob-orc file with every `api_url` set to the Assembly Line
orchestrator. Do it with a script that writes the file and prints only profile names, mode
`0600`:

```bash
mkdir -p ~/.assemblyline/al-orc
sed -E 's#^( +api_url:).*#\1 https://orchestrator.assemblyline.sh#' ~/.fob/fob-orc/config.yml \
  > ~/.assemblyline/al-orc/config.yml
chmod 600 ~/.assemblyline/al-orc/config.yml
for p in $(grep -E '^  [A-Za-z0-9_-]+:$' ~/.assemblyline/al-orc/config.yml | tr -d ' :'); do
  al-orc --profile "$p" status | tail -3
done
```

Do the same on every machine that runs a factory session. Install the CLIs the way the fob
ones are installed there (often a checkout plus `npm link`).

## Start the factory session

On the worker's machine:

```bash
git clone git@github.com:<org>/factory-<name>.git && cd factory-<name> && npm install
cp <worker-dir>/.env .env && chmod 600 .env
sed -i -e 's#^ORCHESTRATOR_URL=.*#ORCHESTRATOR_URL=https://orchestrator.assemblyline.sh#' \
       -e 's#^WORKER_LOCATION=#FACTORY_LOCATION=#' .env      # macOS: sed -i ''
grep -E '^(ORCHESTRATOR_URL|FACTORY_LOCATION)=' .env           # the only values you print
pm2 start src/index.js --name factory-<name> --cwd "$PWD"
pm2 logs factory-<name> --lines 30 --nostream
```

Expect `Session established: <id>` and the right location. A worker and a factory can run
side by side on one machine at the same location: each orchestrator allows one active
session per org and location, and they are different orchestrators.

Check the temp pruner before copying old bins: if `TEMP_PRUNER_DRY_RUN` isn't `true` and
`TEMP_TTL_*` is set, the copied folders may be older than the TTL and get deleted on the next
sweep. The worker had the same settings, so they normally match.

## Move one line

1. **Switch it off on FinOpsBricks.** In the worker repo, set `schedule_enabled: false` on
   the line's scheduled stations, push each with `fob-orc stations push <file>`, and commit
   (`chore: <LINE> moved to factory-<name>`). Check `fob-orc stations list` shows them off.
   Schedules live in the orchestrator, so this stops new runs at once. The worker's bin
   watches go idle when nothing new arrives; they don't need a restart.
2. **Wait for idle.** `fob-orc work-records list --station <ST> --limit 1` for each station
   shows nothing running, and the worker's `temp/stations/<ST>/doing` and `input` are empty.
3. **Carry the state.** `cp -a <worker>/temp/stations/<ST> <factory>/temp/stations/` for every
   station of the line. Compare registry line counts before and after.
4. **Switch it on here.** In the factory repo, set the line's flags back to what the worker
   had, then `al-orc stations push <file>` for each, commit and push. On the machine,
   `git pull` and `pm2 restart factory-<name>`: watches are read from the station files when
   the session starts. If a cron slot passed since the station's `last_run_at`, the scheduler
   runs it within a minute of the push: switching an hourly station on at :29 runs the :00
   slot straight away. Switch on just after a slot, and treat that first run as the check in
   step 5.
5. **Watch it.** The scheduler runs a station when its cron is due after `last_run_at`, so
   an imported station fires at its next slot. Then start the head by hand with `al-orc
   stations run <HEAD>`. In both reports, items seen before must show as skipped. When a run
   seeds something new, check that the watched stations downstream pick it up.

## Move every line at once

Simpler when every line in the plan moves to this one factory session at one location, and
the user accepts a pause of a few minutes. It replaces steps 1–4 above for all lines:

1. Switch every scheduled station off on FinOpsBricks (`fob-orc stations push`, commit), just
   after a cron slot.
2. Wait until every bin is idle (`doing/` and `input/` empty, nothing running), then stop the
   worker: `pm2 stop worker-<name> && pm2 save`. With the worker stopped, its bin watches
   can't fire either.
3. Copy the whole folder: `cp -a <worker>/temp/stations/. <factory>/temp/stations/`. Compare
   registry line counts and any watermark files.
4. Switch every line's flags on in the factory, push the stations, commit, pull on the machine
   and restart the factory session.

Then watch each line as in step 5. Phase 7's stop is already done; still check nothing else
of the worker is active on FinOpsBricks.

## Rollback

For one line: switch its triggers off in the factory (station files, push, restart), copy
any newer state back to the worker's `temp/`, and switch the schedule back on with
`fob-orc stations push`. Nothing in the worker repo was deleted, so the worker carries on
where it was.

## Stop the worker

Only when every line in the plan has moved. List what the worker still has active on
FinOpsBricks (scheduled or watched stations at its location, recent runs), and show it to
the user. Then `pm2 stop worker-<name> && pm2 save`, so it stays stopped after a reboot.
Copy its run logs: `rsync -a --ignore-existing <worker>/temp/work_records/
<factory>/temp/work_records/` (lib-factory uses the same layout, and imported work records
keep their ids).

## Retire the worker

After a week of clean runs, with the user's yes at each step:

1. **Nothing left behind.** In the worker checkout on the machine that ran it: `git status`
   clean, nothing unpushed, no stashes or extra branches. Then list every file outside git
   (`temp/`, `data/`, `.env*`, other ignored files) that has no counterpart in the factory
   checkout. A workpiece that moved to another bin since the copy counts as carried; anything
   else is copied over or explained.
2. **Other copies.** If a sync tool (unison, Syncthing, Dropbox) mirrors the folder to other
   machines, check those copies hold nothing the main one lacks, and delete on every machine,
   or the sync brings the folder back or deletes the wrong side.
3. **Backup.** `tar czf <archive-dir>/worker-<name>-<date>.tar.gz --exclude=node_modules
   worker-<name>`, mode `0600` (it holds `.env`). Outside the workspace, so it doesn't
   confuse anyone.
4. **Archive the repo.** `gh repo edit <org>/worker-<name> --description "Archived: moved to
   <org>/factory-<name>"`, then `gh repo archive <org>/worker-<name> --yes`. The factory's
   `finopsbricks` remote still fetches from it.
5. **Remove it.** `pm2 delete worker-<name> && pm2 save`, delete the checkout on every
   machine, and drop it from any fleet or editor config that lists worker paths.
