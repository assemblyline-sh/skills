# Assembly Line skills

Skills for Claude Code that design, build, debug and migrate [Assembly Line](https://assemblyline.sh)
factories: the lines, stations and steps that run your repeatable work.

```
/plugin marketplace add assemblyline-sh/skills
/plugin install assemblyline@assemblyline
```

Then ask for the job in plain words ("migrate worker-acme to a factory"), or call a skill by
name:

```
/assemblyline:migrate-worker-to-factory ~/code/worker-acme
```

The skill surveys the repo first and writes a run plan before changing anything:

```
== Lines (location) and the stations in this repo that belong to each
IN  location=acme-office-pc  stations here=3
RC  location=acme-office-pc  stations here=2

Station triggers:
  IN0        line=IN       cron "0 * * * *" UTC
  IN1        line=IN       bin watch  [lib-worker slug]
  IN2        line=IN       bin watch  [lib-worker slug]
  RC0        line=RC       manual
  RC1        line=RC       manual  [lib-worker slug]
```

Docs: [assemblyline.sh](https://assemblyline.sh) · Agents: [assemblyline.sh/llms.txt](https://assemblyline.sh/llms.txt)

## Skills

Grouped by where you are with a line. Each skill is a folder in [`skills/`](skills/): a short
`SKILL.md` with the procedure, and reference files it opens only when it needs them.

| Stage | Skill | What it does | Status |
|---|---|---|---|
| Migrate | [`migrate-worker-to-factory`](skills/migrate-worker-to-factory/SKILL.md) | Converts a FinOpsBricks `worker-*` repo to an Assembly Line `factory-*` repo, then moves its lines live one at a time without running any line on two engines | Available |
| Design | `design-a-line` | Turns a repeated job into a line: stations, workpieces, bins, triggers | Planned |
| Build | `build-a-station` | Writes a station's steps, reports and tests | Planned |
| Run | `run-a-line` | Starts, schedules and watches a line; reads work records | Planned |
| Debug | `debug-a-line` | Finds why a workpiece failed or a line stalled, and fixes it | Planned |

## Install

**Claude Code plugin** (recommended): the two commands at the top. Update with
`/plugin marketplace update assemblyline`.

**One skill, by hand:** copy its folder into `~/.claude/skills/` (every project) or
`.claude/skills/` (one project). It's then available as `/<skill-name>`.

**Try a change before it's merged:** `claude --plugin-dir /path/to/this/repo`.

## How these skills are written

- **Thin skill, deep references.** `SKILL.md` holds the procedure and the rules; tables,
  catalogues and edge cases live in files next to it, linked from the step that needs them.
- **State lives in your repo, never in the skill.** A skill that runs over days (like a
  migration) keeps its plan and progress in a WIP file in your repo.
- **Asks before acting outside the repo.** Pushing definitions, switching schedules, starting
  or stopping processes: the skill shows the change and waits for a yes.
- **Never prints secrets.** `.env` files are read by key name only.
- **Fictional examples** (`acme`, `globex`) everywhere.

## Contributing

New skills and fixes are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the folder
layout, the frontmatter, and how to test a skill locally.

## License

[MIT](LICENSE)
