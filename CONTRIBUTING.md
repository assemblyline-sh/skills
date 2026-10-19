# Contributing

## Adding a skill

One folder per skill in `skills/`, named for the job in kebab case (`debug-a-line`):

```
skills/debug-a-line/
├── SKILL.md            # the procedure; under ~200 lines
├── <topic>.md          # reference files SKILL.md links to (tables, catalogues, edge cases)
└── scripts/            # optional helpers the skill runs; read-only unless the step says otherwise
```

`SKILL.md` starts with frontmatter:

```yaml
---
name: debug-a-line
description: <what it does, then "Use when …" with the words people actually say>
argument-hint: "[line code]"
---
```

The `description` is how Claude decides to use the skill, so name the job and the phrases
that should trigger it.

## Rules

- **Procedure in the skill, depth in references.** If a section would make sense as a
  standalone doc, move it to a reference file and link to it from the step that needs it.
- **No run state in the skill.** Plans, trackers and logs go in the user's repo
  (`docs/wip/<task>.md`).
- **Ask before acting outside the working repo**, and say so in the skill.
- **Never print secrets.** Scripts read `.env` by key name only.
- **Fictional examples only:** `acme`, `globex`, `hooli`. No real customer, person or
  company names, no hostnames, IPs or org ids.
- Scripts are `bash` with `set -euo pipefail`, run on macOS and Linux, and need nothing
  beyond `node`, `git` and standard tools.

## Testing locally

```bash
claude plugin validate .                 # manifests
claude --plugin-dir .                    # a session with this checkout's skills loaded
```

In that session, run the skill on a throwaway copy of a real repo. After editing a reference
file or script, run `/reload-plugins`.

## Changes

Add a line under `Unreleased` in [CHANGELOG.md](CHANGELOG.md), bump `version` in
`.claude-plugin/plugin.json` and `marketplace.json` when releasing, and open a pull request.
