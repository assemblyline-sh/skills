# Run plan

Written in phase 1, into `docs/wip/migrate-from-worker-<name>.md` in the factory repo. It
decides the order lines move in and what each move involves. One row per line that this repo
owns (it holds the line's station files).

## Columns

| Column | How to fill it |
|---|---|
| Line | Line code |
| Location | From the line file. Note any location the worker doesn't run on: ask the user where it runs before planning it |
| Trigger | For each station: cron schedule, bin watch, intake watch (`watch_path`), or manual. Read the station files, then compare with `al-orc stations show` (the orchestrator holds the live schedule) |
| Reads | What the steps read from outside: APIs, mailboxes, folders, sheets |
| Writes outside its bins | Uploads, emails sent or moved, rows appended, files renamed. Read the step code; the station description is often out of date |
| If run twice | What a duplicate run costs: harmless (read-only), duplicate rows or uploads, double emails, double renames |
| State to carry | Intake registries (`temp/stations/<HEAD>/intake-registry.jsonl`), waiting workpieces in `output/` and `input/`, parked folders such as `needs_approval/`. Note sizes (`du -sh`) |
| Order and plan | Position and anything special about the move |

## Ordering

1. Read-only lines and lines that only produce a report. They prove the session,
   credentials and reports, and running them on both engines does no harm.
2. Manual lines. Moving them is copying their state; they don't run until someone starts
   them, from `al-orc` from now on. Don't start a manual line that writes outside its bins
   just to test it: leave the first run to the user.
3. Scheduled or watched lines that write outside their bins. One at a time, switched off on
   FinOpsBricks just before a cron slot and switched on here for the next one.
4. Lines at another location: they need a second factory session on that machine.

Not ported: lines with no line file, lines whose steps read `item_snapshot`, and lines whose
stations live in another repo. Say so in the plan rather than dropping them silently.

## Example

| Line | Location | Trigger | Reads | Writes outside its bins | If run twice | Order and plan |
|---|---|---|---|---|---|---|
| RC | acme-office-pc | manual | ledger API | nothing (report only) | harmless | **1st.** Run on both to compare |
| IN | acme-office-pc | IN0 hourly, IN1–2 bin watch | invoices mailbox | uploads to the ledger (IN1), moves the email (IN2) | duplicate uploads | **2nd.** Switch off IN0 on FinOpsBricks before :00, copy `IN0/intake-registry.jsonl`, switch on here |
| AP | acme-office-pc | manual head, AP1–3 bin watch | approvals folder | renames files, writes periods | double renames | **3rd.** Copy `AP1/output/needs_approval` too, or clear pending approvals on the worker first |
